# frozen_string_literal: true

require "spec_helper"

RSpec.describe "Feedback", type: :request do
  # No FEEDBACK_TO_EMAIL/FEEDBACK_FROM_EMAIL in the test env, so Feedbacks::Notify
  # short-circuits: these specs exercise routing + persistence with no network.
  describe "GET /feedback" do
    it "renders the form" do
      get "/feedback"

      expect(last_response.status).to eq(200)
      expect(last_response.body).to include('data-testid="feedback-form"')
      expect(last_response.body).to include('data-testid="feedback-message"')
      expect(last_response.body).to include('data-testid="feedback-email"')
    end

    it "marks the message required and the email not" do
      get "/feedback"

      expect(last_response.body).to match(/id="feedback-message"[^>]*\brequired\b/m)
      expect(last_response.body).not_to match(/id="feedback-email"[^>]*\brequired\b/m)
      expect(last_response.body).to match(/for="feedback-email".*?Optional/m)
    end

    it "carries the originating page into a hidden field" do
      get "/feedback", from: "http://example.org/q/abc"

      expect(last_response.body).to include('name="page" value="http://example.org/q/abc"')
    end

    it "never names the destination address" do
      get "/feedback"

      expect(last_response.body).not_to include("hey.com")
    end
  end

  describe "POST /feedback" do
    it "stores the feedback and says thanks" do
      post "/feedback", message: "The MLS blurbs are great"

      expect(last_response.status).to eq(201)
      expect(last_response.body).to include('data-testid="feedback-thanks"')
      expect(Feedback.recent.first.message).to eq("The MLS blurbs are great")
    end

    it "stores an optional email and the page" do
      post "/feedback", message: "Hi", email: "me@example.com", page: "http://example.org/q/abc"

      feedback = Feedback.recent.first
      expect(feedback.email).to eq("me@example.com")
      expect(feedback.page).to eq("http://example.org/q/abc")
    end

    it "accepts a submission with no email at all" do
      post "/feedback", message: "Anonymous note", email: ""

      expect(last_response.status).to eq(201)
      expect(Feedback.recent.first.email).to be_nil
    end

    it "re-renders with an error and the typed message when it is blank" do
      post "/feedback", message: "  "

      expect(last_response.status).to eq(422)
      expect(last_response.body).to include('data-testid="feedback-message-error"')
      expect(Feedback.count).to eq(0)
    end

    it "re-renders with an error when the email is malformed" do
      post "/feedback", message: "Hi", email: "nope"

      expect(last_response.status).to eq(422)
      expect(last_response.body).to include('data-testid="feedback-email-error"')
      expect(last_response.body).to include("Hi")
      expect(Feedback.count).to eq(0)
    end

    it "shows a honeypot submission the same thanks page, storing nothing" do
      post "/feedback", message: "spam", Feedbacks::Create::HONEYPOT_FIELD => "http://spam.example"

      expect(last_response.status).to eq(200)
      expect(last_response.body).to include('data-testid="feedback-thanks"')
      expect(Feedback.count).to eq(0)
    end
  end

  describe "the link on a finished result" do
    it "appears on a shared club result" do
      result = QuizResult.create(slug: "fbk-club", answers: [0] * 10, weights: [1, 1, 1, 1],
                                 pick: League.default.scored_teams.first.name, league_id: League.default.id)

      get "/q/#{result.slug}"

      expect(last_response.body).to include('data-testid="feedback-link"')
      expect(last_response.body).to include("Have any feedback?")
    end

    it "appears on a shared football profile" do
      result = QuizResult.create(slug: "fbk-profile", answers: [0] * 10, weights: [1, 1, 1, 1],
                                 pick: "An archetype", profile: true)

      get "/q/#{result.slug}"

      expect(last_response.body).to include('data-testid="feedback-link"')
    end

    it "is offered on the quiz page's client-rendered result" do
      get "/"

      expect(last_response.body).to include("Have any feedback?")
    end
  end
end
