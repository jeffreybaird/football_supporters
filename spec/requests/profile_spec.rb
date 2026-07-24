# frozen_string_literal: true

require "spec_helper"
require "json"

RSpec.describe "Football Profile", type: :request do
  def json_post(path, payload)
    post path, payload.to_json, { "CONTENT_TYPE" => "application/json" }
  end

  describe "GET /leagues" do
    it "returns the all-leagues dataset with shared keys hoisted once" do
      get "/leagues"

      expect(last_response).to be_ok
      expect(last_response.content_type).to include("application/json")
      body = JSON.parse(last_response.body)
      expect(body.keys).to include("AXES", "Q", "SLIDERS", "ARCHETYPE", "LEAGUES")
      expect(body["LEAGUES"].length).to eq(League.active.ordered.all.count { |l| l.scored_teams.any? })
      expect(body["LEAGUES"].first.keys).not_to include("AXES", "Q", "SLIDERS")
    end
  end

  describe "POST /quizzes with profile: true" do
    it "persists a profile and returns its share url" do
      json_post "/quizzes", { answers: Array.new(13, 0), weights: [5, 5, 5, 5], profile: true }

      expect(last_response.status).to eq(201)
      body = JSON.parse(last_response.body)
      expect(body["url"]).to include("/q/#{body["slug"]}")
      record = QuizResult.first(slug: body["slug"])
      expect(record.profile?).to be(true)
      expect(record.league_id).to be_nil
    end

    it "returns 422 for an invalid profile payload" do
      json_post "/quizzes", { answers: [0, 1], weights: [5, 5, 5, 5], profile: true }

      expect(last_response.status).to eq(422)
      expect(QuizResult.count).to eq(0)
    end
  end

  describe "GET /q/:slug for a profile" do
    let(:record) do
      Quiz::CreateProfile.call(attrs: { "answers" => Array.new(13, 0), "weights" => [5, 5, 5, 5] }).value!
    end

    it "server-renders each league's winner, the archetype, and share controls" do
      get "/q/#{record.slug}"

      expect(last_response).to be_ok
      body = last_response.body
      expect(body).to include('data-testid="profile-archetype"')
      %w[premier-league bundesliga ligue-1 mls nwsl].each do |slug|
        expect(body).to include("profile-league-#{slug}")
      end
      # the archetype label (stored in pick) and sentence are rendered
      expect(body).to include(record.pick)
      expect(body).to include('data-testid="share-url"')
      expect(body).to include("/js/share.js")
      expect(body).to include('property="og:title"')
    end

    it "makes each league an expandable disclosure revealing the full blurb" do
      get "/q/#{record.slug}"

      body = last_response.body
      # native <details>/<summary> disclosure — no JS, keyboard accessible
      expect(body).to include('<details class="profile__league"')
      expect(body).to include("<summary")
      # the full (multi-sentence) blurb of a winning team is present, not just its first sentence
      profile = Quiz::ProfileScore.call(answers: Array.new(13, 0), weights: [5, 5, 5, 5])
      full_blurb = profile.leagues.map { |e| e.pick.blurb }.find { |b| b.include?(". ") }
      expect(full_blurb).not_to be_nil
      expect(body).to include(Rack::Utils.escape_html(full_blurb))
    end
  end

  it "still renders a single-league result for a non-profile slug (regression)" do
    record = QuizResult.create(slug: "single01", answers: Array.new(13, 0), weights: [5, 5, 5, 5], pick: "Everton")

    get "/q/#{record.slug}"

    expect(last_response).to be_ok
    expect(last_response.body).to include('data-testid="result"')
    expect(last_response.body).not_to include('data-testid="profile-archetype"')
  end
end
