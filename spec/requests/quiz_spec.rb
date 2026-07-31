# frozen_string_literal: true

require "spec_helper"
require "json"

RSpec.describe "Quiz", type: :request do
  def json_post(path, payload)
    post path, payload.to_json, { "CONTENT_TYPE" => "application/json" }
  end

  def create_record(slug: "share01", pick: "Everton")
    QuizResult.create(slug:, answers: Array.new(13, 0), weights: [5, 5, 5, 5], pick:)
  end

  describe "GET /" do
    it "serves the quiz with its embedded dataset" do
      get "/"

      expect(last_response).to be_ok
      expect(last_response.body).to include("window.QUIZ_DATA")
      expect(last_response.body).to include('id="app-src"')
    end

    # The client view trims blurbs to their first sentence too. It must use the
    # shared firstSentence() helper, not a bare split on ". ", or "St. Pauli"
    # gets cut in half on the end-of-quiz screen (the /q/:slug pages already use
    # App#first_sentence and are correct).
    it "trims client-rendered blurbs with the shared firstSentence helper" do
      get "/"

      expect(last_response.body).to include('src="/js/text.js"')
      expect(last_response.body).not_to include('.split(". ")[0]')
    end
  end

  describe "Football Profile as the default mode" do
    it "starts a bare / in profile mode, with the all-leagues bundle embedded" do
      get "/"

      expect(last_response).to be_ok
      expect(last_response.body).to include("window.QUIZ_START_PROFILE = true")
      expect(last_response.body).to include("<title>Your Football Profile</title>")
      # Embedded, not left to a GET /leagues fetch on the critical path.
      expect(last_response.body).to include("window.QUIZ_PROFILE = {")
      expect(last_response.body).not_to include("window.QUIZ_PROFILE = null")
    end

    it "starts in profile mode for an explicit ?league=profile" do
      get "/?league=profile"

      expect(last_response.body).to include("window.QUIZ_START_PROFILE = true")
      expect(last_response.body).to include("<title>Your Football Profile</title>")
    end

    it "starts /coach in profile mode too" do
      get "/coach"

      expect(last_response.body).to include("window.QUIZ_START_PROFILE = true")
      expect(last_response.body).to include("window.QUIZ_COACH = true")
    end

    it "starts in single-league mode when a league slug is asked for" do
      get "/?league=#{League.default.slug}"

      expect(last_response.body).to include("window.QUIZ_START_PROFILE = false")
      expect(last_response.body).to include("window.QUIZ_PROFILE = null")
      # Asserted on <title> — "Your Football Profile" also appears as a literal
      # in the client script (installProfile), so a bare include would pass here.
      expect(last_response.body).to include("<title>Which Premier League Club Should You Support?</title>")
    end

    # The league globals seed the client either way, so leaving profile mode
    # needs no fetch.
    it "embeds the single-league dataset even when starting in profile mode" do
      get "/"

      expect(last_response.body).to include("window.QUIZ_DATA")
      expect(last_response.body).to include("Man United")
    end
  end

  # The intro asterisk is only meaningful if the note it points at ships with it.
  # The client script is served as inert text and transpiled in the browser, so a
  # request spec can only assert both halves are present and wired to the same
  # anchor — that is enough to catch one being edited away without the other.
  describe "the local-club footnote" do
    it "ships the footnote text and the anchor its marker links to" do
      get "/"

      expect(last_response.body).to include("If you have a local club, support them!")
      expect(last_response.body).to include('const FOOTNOTE_ID = "local-club-note"')
      expect(last_response.body).to include("<FootnoteMark />")
      expect(last_response.body).to include("<LocalClubNote />")
    end
  end

  # On touch devices a tap leaves a lingering :hover on the tapped element. The
  # answer buttons are keyed by position and reused across questions, so a stale
  # hover would light up the same slot on the next question before it is chosen.
  # Gating the hover affordance behind `@media (hover: hover)` keeps it to real
  # pointer devices. The client script is inert text here, so assert the qbtn
  # hover rule ships inside that media query.
  describe "answer-button hover on touch devices" do
    it "gates the option hover highlight behind a hover-capable media query" do
      get "/"

      expect(last_response.body).to include("@media (hover: hover)")
      # No `}` may appear between the media query's opening brace and the qbtn
      # hover rule — that proves the rule sits inside the query, not after it.
      expect(last_response.body).to match(/@media \(hover: hover\)\s*\{[^}]*\.qbtn:hover/m)
    end
  end

  # A 6px-tall range input is nearly impossible to drag with a thumb. The input's
  # own box is the drag target, so it has to be tall enough to hit (44px, the WCAG
  # touch-target minimum) with the visible track painted by ::track instead. The
  # client script is inert text here, so assert the rules ship.
  describe "slider drag target on touch devices" do
    it "gives the range input a 44px drag target with the track drawn separately" do
      get "/"

      expect(last_response.body).to match(/input\[type=range\]\{[^}]*height:44px/m)
      expect(last_response.body).to include("input[type=range]::-webkit-slider-runnable-track")
      expect(last_response.body).to include("input[type=range]::-moz-range-track")
    end

    it "lets a vertical swipe over the slider still scroll the page" do
      get "/"

      expect(last_response.body).to match(/input\[type=range\]\{[^}]*touch-action:pan-y/m)
    end
  end

  describe "coach view gating" do
    it "keeps coach view off on the standard page" do
      get "/"

      expect(last_response.body).to include("window.QUIZ_COACH = false")
      expect(last_response.body).not_to include("window.QUIZ_COACH = true")
    end

    it "enables coach view only at /coach" do
      get "/coach"

      expect(last_response).to be_ok
      expect(last_response.body).to include("window.QUIZ_COACH = true")
    end
  end

  describe "league selection" do
    # A second active league (position 1, so it never displaces the default) with
    # one scorable club — enough to serve its page and store a result against it.
    def second_league
      lg = League.create(slug: "test-liga", name: "Test Liga", position: 1)
      Team.create(league_id: lg.id, name: "Barcelona", vibe: 9, play: 9, ethics: 5, fanbase: 9,
                  blurb: "Més que un club.", position: 0)
      lg
    end

    it "injects the league picker options" do
      get "/"

      expect(last_response.body).to include("window.QUIZ_LEAGUES")
      expect(last_response.body).to include("Premier League")
    end

    it "serves a chosen league's dataset and title via ?league=" do
      second_league

      get "/?league=test-liga"

      expect(last_response).to be_ok
      expect(last_response.body).to include("Which Test Liga Club Should You Support?")
      expect(last_response.body).to include("Barcelona")
    end

    it "falls back to the default league for an unknown slug" do
      get "/?league=does-not-exist"

      expect(last_response.body).to include("Which Premier League Club Should You Support?")
    end

    it "serves a league's dataset as JSON so the page can switch without a reload" do
      second_league

      get "/leagues/test-liga"

      expect(last_response).to be_ok
      expect(last_response.content_type).to include("application/json")
      body = JSON.parse(last_response.body)
      expect(body["LEAGUE"]).to eq("slug" => "test-liga", "name" => "Test Liga")
      expect(body["TEAMS"].keys).to eq(["Barcelona"])
      expect(body["FLAVOR"]["Barcelona"]).to eq("Més que un club.")
      expect(body["CHOOSER_THRESHOLD"]).to eq(0.25)
    end

    it "returns 404 for an unknown or inactive league dataset" do
      League.create(slug: "hidden-liga", name: "Hidden", active: false, position: 9)

      get "/leagues/hidden-liga"
      expect(last_response.status).to eq(404)

      get "/leagues/nope"
      expect(last_response.status).to eq(404)
    end

    it "stores a submitted quiz against the chosen league" do
      lg = second_league

      json_post "/quizzes", { answers: Array.new(13, 0), weights: [5, 5, 5, 5], league: "test-liga" }

      expect(last_response.status).to eq(201)
      expect(QuizResult.first.league_id).to eq(lg.id)
    end
  end

  describe "POST /quizzes" do
    it "persists a completed quiz and returns its share url" do
      json_post "/quizzes", { answers: Array.new(13, 0), weights: [5, 5, 5, 5] }

      expect(last_response.status).to eq(201)
      body = JSON.parse(last_response.body)
      expect(body["slug"]).to be_a(String)
      expect(body["url"]).to include("/q/#{body["slug"]}")
      expect(QuizResult.count).to eq(1)
      expect(QuizResult.first.pick).to eq("Man United")
      expect(QuizResult.first.league_id).to eq(League.default.id)
    end

    it "returns 422 for an invalid payload" do
      json_post "/quizzes", { answers: [0, 1], weights: [5, 5, 5, 5] }

      expect(last_response.status).to eq(422)
      expect(JSON.parse(last_response.body)["error"]).to eq("validation")
      expect(QuizResult.count).to eq(0)
    end

    it "fingerprints the taker from their ip and browser so takers can be grouped" do
      header "User-Agent", "Mozilla/5.0 (Test)"
      json_post "/quizzes", { answers: Array.new(13, 0), weights: [5, 5, 5, 5] }

      expect(last_response.status).to eq(201)
      expect(QuizResult.first.fingerprint).to match(/\A[0-9a-f]{64}\z/)
    end

    it "gives two submissions from the same ip + browser the same fingerprint" do
      header "User-Agent", "Mozilla/5.0 (Test)"
      json_post "/quizzes", { answers: Array.new(13, 0), weights: [5, 5, 5, 5] }
      json_post "/quizzes", { answers: Array.new(13, 0), weights: [5, 5, 5, 5] }

      fingerprints = QuizResult.all.map(&:fingerprint)
      expect(fingerprints.uniq.length).to eq(1)
    end

    it "links the returned clubs to the stored result" do
      json_post "/quizzes", { answers: Array.new(13, 0), weights: [5, 5, 5, 5] }

      record = QuizResult.first
      expect(record.teams.map(&:name)).to include(record.pick)
    end
  end

  describe "GET /q/:slug" do
    it "renders the shared result server-side" do
      record = create_record(slug: "united01", pick: "Man United")

      get "/q/#{record.slug}"

      expect(last_response).to be_ok
      expect(last_response.body).to include("Man United")
      # the flavour text is rendered, not just the name (apostrophe-free snippet,
      # since ERB auto-escapes apostrophes)
      expect(last_response.body).to include("Every August, United fans decide this is the year")
      # share controls + populated link
      expect(last_response.body).to include('data-testid="share-url"')
      expect(last_response.body).to include("/q/united01")
      expect(last_response.body).to include("/js/share.js")
      # social preview metadata
      expect(last_response.body).to include('property="og:title"')
    end

    # The deploy hands the process CREST_BASE_URL="" whenever the CDN variable is
    # unconfigured, and the shared pages are the only crest path with no client-
    # side `|| "/images"` to absorb it. Drive the real derivation for that env so
    # these fail if the fallback ever stops covering blank: a bare "" base emits
    # src="/premier-league/....png", which 404s on the host.
    it "renders crests from public/images when the CDN base is blank" do
      stub_const("App::CREST_BASE_URL", App.crest_base_url({ "CREST_BASE_URL" => "" }))
      record = create_record(slug: "united02", pick: "Man United")

      get "/q/#{record.slug}"

      expect(last_response).to be_ok
      expect(last_response.body).to include('src="http://example.org/images/premier-league/')
      expect(last_response.body).not_to match(%r{src="/?premier-league/})
      # The OG image is built by the same helper and is what unfurls in a share.
      expect(last_response.body).to include('content="http://example.org/images/premier-league/')
    end

    it "renders a shared profile's crests from public/images when the CDN base is blank" do
      stub_const("App::CREST_BASE_URL", App.crest_base_url({ "CREST_BASE_URL" => "" }))
      QuizResult.create(slug: "prof01", answers: Array.new(13, 0), weights: [5, 5, 5, 5],
                        pick: "The Purist", profile: true)

      get "/q/prof01"

      expect(last_response).to be_ok
      expect(last_response.body).to include('data-testid="profile-result"')
      expect(last_response.body).to include('src="http://example.org/images/')
      expect(last_response.body).not_to match(%r{src="/?[a-z-]+/\d+-[^"]*\.png"})
    end

    it "returns 404 for an unknown slug" do
      get "/q/does-not-exist"

      expect(last_response.status).to eq(404)
      expect(last_response.body).to include('data-testid="not-found"')
    end

    it "does not surface a soft-deleted result" do
      record = create_record(slug: "hidden1")
      record.soft_delete!

      get "/q/#{record.slug}"

      expect(last_response.status).to eq(404)
    end
  end
end
