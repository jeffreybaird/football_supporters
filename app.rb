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
    def first_sentence(text)
      "#{text.split('. ').first}."
    end

    # Absolute, URL-encoded crest path (nil when the team has no crest on file).
    def crest_url(file)
      file && url("/images/#{ERB::Util.url_encode(file)}")
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

  # Persist a completed quiz and return its shareable slug. Called by the quiz's
  # fetch() on "Show my club"; body is JSON { answers: [...], weights: [...] }.
  post "/quizzes" do
    content_type :json
    result = Quiz::Create.call(league: League.default, attrs: parse_json_body)
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

    @league = @record.league || League.default
    halt 404, erb(:"quiz/not_found") unless @league

    @teams = @league.scored_teams
    @score = Quiz::Score.call(teams: @teams, answers: @record.answers, weights: @record.weights)
    @share_url = url("/q/#{@record.slug}")

    pick = @score.pick
    @page_title = "I should support #{pick.name} — Which #{@league.name} Club Should You Support?"
    @meta_description = first_sentence(pick.blurb)
    @og = { "title" => @page_title, "description" => @meta_description, "url" => @share_url }
    @og["image"] = crest_url(pick.crest) if pick.crest
    erb :"quiz/result"
  end

  private

  def render_quiz(coach:)
    @league = League.default
    @page_title = "Which #{@league.name} Club Should You Support?" if @league
    @quiz_data_json = json_for_script(Quiz::ClientData.call(@league))
    @coach = coach
    erb :"quiz/index"
  end

  def parse_json_body
    request.body.rewind
    JSON.parse(request.body.read)
  rescue JSON::ParserError
    {}
  end
end
