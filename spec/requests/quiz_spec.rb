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

  describe "POST /quizzes" do
    it "persists a completed quiz and returns its share url" do
      json_post "/quizzes", { answers: Array.new(13, 0), weights: [5, 5, 5, 5] }

      expect(last_response.status).to eq(201)
      body = JSON.parse(last_response.body)
      expect(body["slug"]).to be_a(String)
      expect(body["url"]).to include("/q/#{body['slug']}")
      expect(QuizResult.count).to eq(1)
      expect(QuizResult.first.pick).to eq("Everton")
    end

    it "returns 422 for an invalid payload" do
      json_post "/quizzes", { answers: [0, 1], weights: [5, 5, 5, 5] }

      expect(last_response.status).to eq(422)
      expect(JSON.parse(last_response.body)["error"]).to eq("validation")
      expect(QuizResult.count).to eq(0)
    end
  end

  describe "GET /q/:slug" do
    it "renders the shared result server-side" do
      record = create_record(slug: "everton1", pick: "Everton")

      get "/q/#{record.slug}"

      expect(last_response).to be_ok
      expect(last_response.body).to include("Everton")
      # the flavour text is rendered, not just the name (apostrophe-free snippet,
      # since ERB auto-escapes the apostrophe in "People's")
      expect(last_response.body).to include("Everton fans have spent years convinced")
      # share controls + populated link
      expect(last_response.body).to include('data-testid="share-url"')
      expect(last_response.body).to include("/q/everton1")
      expect(last_response.body).to include("/js/share.js")
      # social preview metadata
      expect(last_response.body).to include('property="og:title"')
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
