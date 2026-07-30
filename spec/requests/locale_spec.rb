# frozen_string_literal: true

require "spec_helper"
require "json"

RSpec.describe "Locale and the language switcher", type: :request do
  describe "language negotiation on the quiz page" do
    it "renders English by default (no cookie, no Accept-Language)" do
      get "/"

      expect(last_response.body).to include('<html lang="en">')
      expect(last_response.body).to include("<title>Your Football Profile</title>")
    end

    it "renders French when Accept-Language prefers it" do
      get "/", {}, { "HTTP_ACCEPT_LANGUAGE" => "fr-FR,fr;q=0.9,en;q=0.8" }

      expect(last_response.body).to include('<html lang="fr">')
      expect(last_response.body).to include("<title>Ton Profil Football</title>")
      # localized quiz CONTENT is embedded (question + archetype copy)
      expect(last_response.body).to include("Un match sans aucune de tes")
      expect(last_response.body).to include("Le Chasseur de gloire")
      # localized UI dictionary is embedded for the client
      expect(last_response.body).to include("Si tu as un club local")
    end

    it "lets a locale cookie override the Accept-Language header" do
      get "/", {}, { "HTTP_ACCEPT_LANGUAGE" => "en-US,en", "HTTP_COOKIE" => "locale=fr" }

      expect(last_response.body).to include('<html lang="fr">')
      expect(last_response.body).to include("<title>Ton Profil Football</title>")
    end

    it "falls back to English for an unsupported Accept-Language" do
      get "/", {}, { "HTTP_ACCEPT_LANGUAGE" => "de-DE,de" }

      expect(last_response.body).to include('<html lang="en">')
    end
  end

  describe "the language drawer" do
    it "renders on every page with an option per supported locale" do
      get "/"

      expect(last_response.body).to include('data-testid="language-trigger"')
      expect(last_response.body).to include('data-testid="language-option-en"')
      expect(last_response.body).to include('data-testid="language-option-fr"')
      # each option is a real form submit button, so it works with no JavaScript
      expect(last_response.body).to match(/<button[^>]*name="locale"[^>]*value="fr"/m)
    end

    it "marks the active locale and carries the current path back in return_to" do
      get "/coach", {}, { "HTTP_COOKIE" => "locale=fr" }

      expect(last_response.body).to include('name="return_to" value="/coach"')
      # the French option is the current one
      expect(last_response.body).to match(/value="fr"[^>]*aria-current="true"/m)
    end

    it "shows the trigger label in the active language" do
      get "/"
      expect(last_response.body).to include(">Language<")

      get "/", {}, { "HTTP_COOKIE" => "locale=fr" }
      expect(last_response.body).to include(">Langue<")
    end
  end

  describe "POST /locale" do
    it "stores the chosen locale as a cookie and redirects back" do
      post "/locale", { "locale" => "fr", "return_to" => "/coach" }

      expect(last_response.status).to eq(302)
      expect(last_response.headers["Location"]).to end_with("/coach")
      cookie = Array(last_response.headers["Set-Cookie"]).join("\n")
      expect(cookie).to include("locale=fr")
      expect(cookie).to match(/max-age=31536000/i)
    end

    it "refuses to redirect off-site (open-redirect guard)" do
      post "/locale", { "locale" => "fr", "return_to" => "//evil.example.com" }
      expect(last_response.headers["Location"]).to end_with("/")

      post "/locale", { "locale" => "fr", "return_to" => "https://evil.example.com/x" }
      expect(last_response.headers["Location"]).to end_with("/")

      # "/\\host" is normalised to "//host" by some browsers — also refused.
      post "/locale", { "locale" => "fr", "return_to" => "/\\evil.example.com" }
      expect(last_response.headers["Location"]).to end_with("/")
    end

    it "preserves a legitimate local path with a query string" do
      post "/locale", { "locale" => "en", "return_to" => "/coach?league=profile" }
      expect(last_response.headers["Location"]).to end_with("/coach?league=profile")
    end

    it "stores the default locale rather than an unsupported value" do
      post "/locale", { "locale" => "xx", "return_to" => "/" }

      cookie = Array(last_response.headers["Set-Cookie"]).join("\n")
      expect(cookie).to include("locale=en")
    end

    it "actually changes what the next request renders" do
      post "/locale", { "locale" => "fr", "return_to" => "/" }
      # follow the cookie the response set
      get "/", {}, { "HTTP_COOKIE" => "locale=fr" }

      expect(last_response.body).to include('<html lang="fr">')
    end
  end

  describe "localized JSON datasets" do
    it "serves a league's dataset with French question text when asked in French" do
      get "/leagues/#{League.default.slug}", {}, { "HTTP_ACCEPT_LANGUAGE" => "fr" }

      body = JSON.parse(last_response.body)
      v2 = body["Q"].find { |q| q["id"] == "V2" }
      expect(v2["t"]).to eq("Un match sans aucune de tes équipes. Tu veux")
      # numbers are untouched so the client scores identically
      expect(v2["load"]).to eq(Quiz::Data::Q.find { |q| q["id"] == "V2" }["load"])
    end
  end

  describe "localized server-rendered shared pages" do
    it "renders a shared club result in French" do
      record = QuizResult.create(slug: "loc-club", answers: Array.new(13, 0), weights: [5, 5, 5, 5],
                                 pick: "Man United", league_id: League.default.id)

      get "/q/#{record.slug}", {}, { "HTTP_ACCEPT_LANGUAGE" => "fr" }

      expect(last_response.body).to include('<html lang="fr">')
      expect(last_response.body).to include("Fin du match")
      expect(last_response.body).to include("Faire le quiz")
      expect(last_response.body).to include("Partage ton résultat")
    end

    it "renders a shared football profile with a French archetype" do
      record = Quiz::CreateProfile.call(
        attrs: { "answers" => Array.new(13, 0), "weights" => [5, 5, 5, 5] }
      ).value!

      get "/q/#{record.slug}", {}, { "HTTP_ACCEPT_LANGUAGE" => "fr" }

      expect(last_response.body).to include('<html lang="fr">')
      expect(last_response.body).to include("Fin du match · ton profil football")
      # the archetype label rendered is the French one (ProfileScore localized)
      fr_profile = Quiz::ProfileScore.call(answers: record.answers, weights: record.weights, locale: "fr")
      expect(last_response.body).to include(fr_profile.archetype[:label])
    end

    it "renders the 404 page in French" do
      get "/q/does-not-exist", {}, { "HTTP_ACCEPT_LANGUAGE" => "fr" }

      expect(last_response.status).to eq(404)
      expect(last_response.body).to include("Aucun résultat ici")
    end
  end

  describe "localized feedback form" do
    it "renders the feedback form in French" do
      get "/feedback", {}, { "HTTP_ACCEPT_LANGUAGE" => "fr" }

      expect(last_response.body).to include('data-testid="feedback-form"')
      expect(last_response.body).to include("Envoyer →")
      expect(last_response.body).to match(/for="feedback-email".*?Facultatif/m)
    end
  end
end
