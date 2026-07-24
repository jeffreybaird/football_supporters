# frozen_string_literal: true

require "sinatra/base"
require "securerandom"
require "json"
require "erb"

# The application. Routes stay thin: parse params, call a service object, render.
# Business rules and SQL live in app/services and app/models — never here.
class App < Sinatra::Base
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

    # Absolute, URL-encoded crest path (nil when the team has no crest on file).
    # A crest is a "<league-slug>/<file>" path, so encode each segment and keep
    # the separators — url_encode on the whole string would escape the slash.
    def crest_url(file)
      return unless file

      url("/images/#{file.split("/").map { |seg| ERB::Util.url_encode(seg) }.join("/")}")
    end
  end

  # Liveness/readiness: 200 once the process can reach the DB.
  get "/up" do
    DB.test_connection
    content_type :json
    '{"status":"ok"}'
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

    Quiz::ClientData.call(league).to_json
  end

  # Every active league's dataset in one payload, for the "Football Profile" mode
  # that scores answers against all leagues at once. Fetched lazily when the user
  # picks Profile (see the client's enterProfile).
  get "/leagues" do
    content_type :json
    Quiz::ProfileData.call.to_json
  end

  # Persist a completed quiz and return its shareable slug. Called by the quiz's
  # fetch() on "Show my club"; body is JSON { answers: [...], weights: [...] }.
  post "/quizzes" do
    content_type :json
    attrs = parse_json_body
    result = if attrs["profile"]
               Quiz::CreateProfile.call(attrs:)
             else
               Quiz::Create.call(league: resolve_league(attrs["league"]), attrs:)
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
    @page_title = "I should support #{pick.name} — Which #{@league.name} Club Should You Support?"
    @meta_description = first_sentence(pick.blurb)
    @og = { "title" => @page_title, "description" => @meta_description, "url" => @share_url }
    @og["image"] = crest_url(pick.crest) if pick.crest
    erb :"quiz/result"
  end

  private

  # Server-rendered shared Football Profile: re-score every league and render the
  # per-league winners plus the archetype. Returns the HTML for the route to halt.
  def render_profile(record)
    @profile = Quiz::ProfileScore.call(answers: record.answers, weights: record.weights)
    @share_url = url("/q/#{record.slug}")
    @page_title = "My Football Profile — #{@profile.archetype[:label]}"
    @meta_description = @profile.archetype[:sentence]
    @og = { "title" => @page_title, "description" => @meta_description, "url" => @share_url }
    top = @profile.leagues.max_by(&:sim)
    @og["image"] = crest_url(top.pick.crest) if top&.pick&.crest
    erb :"quiz/profile_result"
  end

  def render_quiz(coach:)
    @league = resolve_league(params["league"])
    @leagues = League.active.ordered.all
    @page_title = "Which #{@league.name} Club Should You Support?" if @league
    @quiz_data_json = json_for_script(Quiz::ClientData.call(@league))
    @leagues_json = json_for_script(@leagues.map { |l| { "slug" => l.slug, "name" => l.name } })
    @coach = coach
    erb :"quiz/index"
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
end
