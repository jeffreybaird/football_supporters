# frozen_string_literal: true

require "sinatra/base"
require "securerandom"
require "json"
require "erb"

require_relative "app/mcp"

# The application. Routes stay thin: parse params, call a service object, render.
# Business rules and SQL live in app/services and app/models — never here.
class App < Sinatra::Base
  # The ?league= value standing for the cross-league Football Profile rather than
  # a league slug. Football Profile is the DEFAULT: a bare "/" starts in it, and
  # this value only appears in the URL once the client has switched modes. Must
  # match PROFILE_SLUG in views/quiz/index.erb.
  PROFILE_PARAM = "profile"

  # Where team crests are served from. Crests live on a CDN (DigitalOcean
  # Spaces) in production; leaving CREST_BASE_URL unset falls back to the copies
  # still committed under public/images, so dev and the test suite need no
  # network. A stored crest is a "<league-slug>/<file>" path and the object keys
  # on the CDN mirror that layout, so only the prefix differs between the two.
  # Any trailing slash is stripped so the joins below can't produce "//".
  #
  # Blank counts as unset. ENV.fetch's default only fires when the variable is
  # absent, but the deploy writes every config line into .env unconditionally,
  # so a CI variable that was never given a value arrives as "CREST_BASE_URL="
  # — present and empty. Left as "", crest_url emits "/<league>/<file>.png" and
  # every server-rendered crest 404s. (The client script masked this with its
  # own `|| "/images"`, so only the shared result pages broke.)
  def self.crest_base_url(env = ENV)
    value = env["CREST_BASE_URL"].to_s.strip
    (value.empty? ? "/images" : value).chomp("/")
  end

  CREST_BASE_URL = crest_base_url

  # How long a chosen language preference sticks (one year, in seconds).
  LOCALE_COOKIE_MAX_AGE = 31_536_000

  # The MCP (Model Context Protocol) server, built once and shared across
  # requests — it is read-only and thread-safe, so one instance serves Puma's
  # whole thread pool. Exposes the supporter/club tools over the /mcp route below,
  # the same handlers the stdio server (bin/mcp) uses.
  MCP_TRANSPORT = MCP::Http.new(MCP.server)

  configure do
    set :root, __dir__
    set :erb, escape_html: true
    set :sessions, secret: ENV.fetch("SECRET_KEY_BASE") { SecureRandom.hex(64) }
    enable :logging
    set :show_exceptions, false if ENV["RACK_ENV"] == "production"
  end

  # Current is the request-scoped data boundary (NOT authorization). Reset it
  # around every request so nothing leaks between them.
  before do
    Current.reset!
    Current.request_id = env["HTTP_X_REQUEST_ID"] || SecureRandom.uuid
  end
  after { Current.reset! }

  helpers do
    # Serialize a Ruby object for safe embedding inside a <script> tag. Uses JS
    # unicode escapes (not HTML entities — those aren't decoded inside a script)
    # so a "</script>", "<!--", or JS line separator in the data can't break out.
    def json_for_script(obj)
      obj.to_json.gsub(/[<>&\u2028\u2029]/) do |c|
        { "<" => "\u003c", ">" => "\u003e", "&" => "\u0026",
          "\u2028" => "\u2028", "\u2029" => "\u2029" }[c]
      end
    end

    def team_initials(name)
      name.split.map { |word| word[0] }.join.slice(0, 3).upcase
    end

    # First sentence of a blurb — used for alternates and OG descriptions.
    # Splitting on ". " breaks a "St." abbreviation into its own chunk, so keep
    # folding chunks in until one doesn't end with a dangling "St".
    def first_sentence(text)
      chunks = text.split(". ")
      sentence = chunks.reduce { |acc, chunk| acc.end_with?("St") ? "#{acc}. #{chunk}" : acc }
      "#{sentence}."
    end

    # Absolute, URL-encoded crest URL (nil when the team has no crest on file).
    # A crest is a "<league-slug>/<file>" path, so encode each segment and keep
    # the separators — url_encode on the whole string would escape the slash.
    #
    # An absolute CREST_BASE_URL (the CDN) is already a full origin and is
    # returned as-is; the local "/images" fallback still goes through url() so
    # OG tags and shared pages get an absolute URL for this host.
    #
    # The CDN's object keys are Unicode-DECOMPOSED (NFD) for the three accented
    # crest names — the upload normalized them — while the copies on disk and
    # the names in Quiz::Seed are composed (NFC). Object keys match byte for
    # byte, so "Köln" in the wrong form is a 403; convert on the way out. This
    # is a no-op for the other 183 crests, whose names are pure ASCII, and is
    # deliberately NOT applied to the local fallback, where the files are NFC.
    def crest_url(file)
      return unless file

      segments = file.split("/").map do |seg|
        ERB::Util.url_encode(remote_crests? ? seg.unicode_normalize(:nfd) : seg)
      end
      path = "#{CREST_BASE_URL}/#{segments.join("/")}"
      remote_crests? ? path : url(path)
    end

    # True when crests come from the CDN rather than public/images. The two
    # stores differ in more than their prefix (see the NFD note above), so the
    # distinction is named rather than re-derived at each use.
    def remote_crests?
      CREST_BASE_URL.start_with?("http://", "https://")
    end

    # The request's locale: an explicit "locale" cookie the visitor chose wins,
    # otherwise their Accept-Language is negotiated, otherwise the default (en).
    # Memoized for the request. Every view reaches text through this via #t.
    def locale
      @locale ||= Translations.resolve(cookie: request.cookies["locale"],
                                       header: request.env["HTTP_ACCEPT_LANGUAGE"])
    end

    # Translate a dotted key in the request's locale (see Translations.t).
    def t(key, **vars)
      Translations.t(key, locale:, **vars)
    end
  end

  # Liveness/readiness: 200 once the process can reach the DB.
  get "/up" do
    DB.test_connection
    content_type :json
    '{"status":"ok"}'
  end

  # Model Context Protocol endpoint (Streamable HTTP). One POST of JSON-RPC in,
  # one JSON response out — read-only and stateless. A remote Claude client adds
  # this URL as a custom connector and calls the same tools bin/mcp exposes over
  # stdio. The transport is a thin adapter; all protocol logic lives in MCP::Server.
  post "/mcp" do
    request.body.rewind
    status_code, type, body = MCP_TRANSPORT.post(request.body.read)
    content_type(type) if type
    status status_code
    body
  end

  # This transport is request/response only — there is no server-initiated stream
  # to open, so a GET has nothing to return.
  get "/mcp" do
    content_type :json
    halt 405, { "Allow" => "POST" }, { error: "method_not_allowed" }.to_json
  end

  # The quiz itself — a client-rendered recommender fed the very same dataset the
  # server scores with, so client and server can never drift.
  get "/" do
    render_quiz(coach: false)
  end

  # Coach's view — the analyst UI (answer loadings, live ranking, similarity
  # table). Deliberately a separate, unlinked URL; the standard quiz shows none
  # of it.
  get "/coach" do
    render_quiz(coach: true)
  end

  # A league's quiz dataset as JSON. The quiz page fetches this when the league
  # picker changes so it can swap datasets without a reload; it is the very same
  # payload the page embeds, so client and server still can't drift.
  get "/leagues/:slug" do
    content_type :json
    league = League.active.first(slug: params["slug"])
    halt 404, { error: "not_found" }.to_json unless league

    Quiz::ClientData.call(league, locale:).to_json
  end

  # Every active league's dataset in one payload, for the "Football Profile" mode
  # that scores answers against all leagues at once. Fetched lazily when the user
  # picks Profile (see the client's enterProfile).
  get "/leagues" do
    content_type :json
    Quiz::ProfileData.call(locale:).to_json
  end

  # Persist a completed quiz and return its shareable slug. Called by the quiz's
  # fetch() on "Show my club"; body is JSON { answers: [...], weights: [...] }.
  post "/quizzes" do
    content_type :json
    attrs = parse_json_body
    fingerprint = Quiz::Fingerprint.call(request)
    result = if attrs["profile"]
               Quiz::CreateProfile.call(attrs:, fingerprint:)
             else
               Quiz::Create.call(league: resolve_league(attrs["league"]), attrs:, fingerprint:)
             end
    if result.success?
      record = result.value!
      status 201
      { slug: record.slug, url: url("/q/#{record.slug}") }.to_json
    else
      status(result.failure.first == :validation ? 422 : 409)
      { error: result.failure.first.to_s }.to_json
    end
  end

  # A shared result — server-rendered so it needs no JavaScript and previews well.
  get "/q/:slug" do
    @record = QuizResult.kept.first(slug: params["slug"])
    halt 404, erb(:"quiz/not_found") unless @record

    # A profile spans every league (league_id nil) — must branch before the
    # single-league default fallback below, or it would render a bogus result.
    halt render_profile(@record) if @record.profile?

    @league = @record.league || League.default
    halt 404, erb(:"quiz/not_found") unless @league

    @teams = @league.scored_teams
    @score = Quiz::Score.call(teams: @teams, answers: @record.answers, weights: @record.weights,
                              **@league.scoring_params)
    @share_url = url("/q/#{@record.slug}")

    pick = @score.pick
    @page_title = t("titles.club_result", name: pick.name, league: @league.name)
    @meta_description = first_sentence(pick.blurb)
    @og = { "title" => @page_title, "description" => @meta_description, "url" => @share_url }
    @og["image"] = crest_url(pick.crest) if pick.crest
    erb :"quiz/result"
  end

  # Persist the visitor's language choice as a cookie and send them back where
  # they were. Posted by the language drawer (views/_language_drawer.erb). A plain
  # form POST so it works without JavaScript; the cookie is what every subsequent
  # request reads via #locale. An unsupported value falls back to the default
  # rather than being stored, so the cookie is always a locale we can serve.
  post "/locale" do
    choice = params["locale"]
    choice = Translations::DEFAULT unless Translations::SUPPORTED.include?(choice)
    response.set_cookie("locale",
                        value: choice, path: "/", max_age: LOCALE_COOKIE_MAX_AGE,
                        same_site: :lax, http_only: true)
    redirect safe_return_to(params["return_to"])
  end

  # The feedback form. `from` carries the page the visitor clicked through from,
  # so a submission arrives with context; it is stored, never rendered back into
  # a link, so it can't be used to bounce anyone elsewhere.
  get "/feedback" do
    @page_title = t("feedback.page_title")
    @from = params["from"]
    @values = {}
    @errors = {}
    erb :"feedback/new"
  end

  # Record feedback and email it onward. A plain form POST — no JavaScript, and
  # the destination address never reaches the client (see Feedbacks::Notify).
  post "/feedback" do
    result = Feedbacks::Create.call(attrs: params)
    if result.success? || result.failure.first == :spam
      # A honeypot hit gets the same page a person gets: telling a bot it was
      # detected only teaches it to try again differently.
      @page_title = t("feedback.thanks_page_title")
      status 201 if result.success?
      erb :"feedback/thanks"
    else
      status 422
      @page_title = t("feedback.page_title")
      @from = params["page"]
      @values = { message: params["message"], email: params["email"] }
      @errors = result.failure.first == :validation ? result.failure.last : { message: t("feedback.generic_error") }
      erb :"feedback/new"
    end
  end

  private

  # Server-rendered shared Football Profile: re-score every league and render the
  # per-league winners plus the archetype. Returns the HTML for the route to halt.
  def render_profile(record)
    @profile = Quiz::ProfileScore.call(answers: record.answers, weights: record.weights, locale:)
    @share_url = url("/q/#{record.slug}")
    @page_title = t("titles.profile_result", label: @profile.archetype[:label])
    @meta_description = @profile.archetype[:sentence]
    @og = { "title" => @page_title, "description" => @meta_description, "url" => @share_url }
    top = @profile.leagues.max_by(&:sim)
    @og["image"] = crest_url(top.pick.crest) if top&.pick&.crest
    erb :"quiz/profile_result"
  end

  def render_quiz(coach:)
    @league = resolve_league(params["league"])
    @leagues = League.active.ordered.all
    # Football Profile is the default landing experience: a bare "/" (or an
    # explicit ?league=profile) starts there. Ask for a league by slug to get
    # that league's single-club quiz instead.
    @profile_start = params["league"].nil? || params["league"] == PROFILE_PARAM
    @page_title = quiz_page_title
    # The single-league dataset is embedded either way: it seeds the client's
    # league globals, so leaving profile mode needs no fetch.
    @quiz_data_json = json_for_script(Quiz::ClientData.call(@league, locale:))
    # Embedded rather than left to the GET /leagues fetch, which in the default
    # mode would sit on every landing's critical path.
    @profile_json = @profile_start ? json_for_script(Quiz::ProfileData.call(locale:)) : "null"
    @leagues_json = json_for_script(@leagues.map { |l| { "slug" => l.slug, "name" => l.name } })
    # The client builds its own <img> src from the same base the server uses for
    # OG tags, so a CDN switch moves both at once.
    @crest_base_json = json_for_script(CREST_BASE_URL)
    # The client's UI dictionary for this locale, English-merged (see
    # Translations.client). The quiz CONTENT (questions/sliders/archetypes) is
    # already localized inside @quiz_data_json/@profile_json above.
    @i18n_json = json_for_script(Translations.client(locale))
    @coach = coach
    erb :"quiz/index"
  end

  # Reads @profile_start / @league, so call it after both are set. Nil when there
  # is no league at all to name — the layout falls back to its own default.
  def quiz_page_title
    return t("titles.profile") if @profile_start
    return unless @league

    t("titles.league", name: @league.name)
  end

  # The active league matching slug, falling back to the default league. Used by
  # the league dropdown (via ?league=) and the quiz submit body.
  def resolve_league(slug)
    (slug && League.active.first(slug:)) || League.default
  end

  def parse_json_body
    request.body.rewind
    JSON.parse(request.body.read)
  rescue JSON::ParserError
    {}
  end

  # Where to send the visitor back to after setting their language. Only a local
  # path is honoured — the root, or "/" followed by a non-slash, non-backslash
  # character. That rejects absolute URLs, scheme-relative "//host", and the
  # "/\host" form some browsers normalise to "//host", so the language switcher
  # can't be turned into an open redirect.
  def safe_return_to(path)
    return "/" unless path.is_a?(String)
    return path if path == "/" || path.match?(%r{\A/[^/\\]})

    "/"
  end
end
