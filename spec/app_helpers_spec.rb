# frozen_string_literal: true

require "spec_helper"

RSpec.describe App do
  # App.new! returns the raw instance without the Rack middleware stack,
  # exposing helper methods directly for unit testing.
  let(:helpers) { App.new! }

  describe "#first_sentence" do
    it "returns only the first sentence of a multi-sentence blurb" do
      text = "Founded in 1902. They play in green and white."

      expect(helpers.first_sentence(text)).to eq("Founded in 1902.")
    end

    it "keeps a mid-sentence St. abbreviation intact instead of truncating on it" do
      text = "St. Louis City is a young MLS club. It plays in the Western Conference."

      expect(helpers.first_sentence(text)).to eq("St. Louis City is a young MLS club.")
    end

    it "returns the whole text unchanged when there is only one sentence" do
      text = "A single sentence with no trailing period"

      expect(helpers.first_sentence(text)).to eq("#{text}.")
    end
  end

  # The deploy writes every config line into .env whether or not the CI variable
  # behind it has a value, so an unconfigured CDN reaches the process as an empty
  # string rather than an absent variable. That is not a base URL: it made every
  # crest on the server-rendered share pages resolve to "/<league>/<file>.png".
  describe ".crest_base_url" do
    it "falls back to public/images when the variable is absent" do
      expect(App.crest_base_url({})).to eq("/images")
    end

    it "falls back to public/images when the variable is set but empty" do
      expect(App.crest_base_url({ "CREST_BASE_URL" => "" })).to eq("/images")
    end

    it "falls back to public/images when the variable is only whitespace" do
      expect(App.crest_base_url({ "CREST_BASE_URL" => "  " })).to eq("/images")
    end

    it "uses a configured CDN origin" do
      expect(App.crest_base_url({ "CREST_BASE_URL" => "https://cdn.example.com/crests" }))
        .to eq("https://cdn.example.com/crests")
    end

    it "strips a trailing slash so the joins can't produce a double separator" do
      expect(App.crest_base_url({ "CREST_BASE_URL" => "https://cdn.example.com/crests/" }))
        .to eq("https://cdn.example.com/crests")
    end
  end

  describe "#crest_url" do
    # url() needs a request to build an absolute URL against; the CDN branch
    # never calls it, so only the fallback examples set one up.
    def with_request
      App.new!.tap { |h| h.instance_variable_set(:@request, Sinatra::Request.new(Rack::MockRequest.env_for("http://example.org/"))) }
    end

    it "returns nil when the team has no crest on file" do
      expect(helpers.crest_url(nil)).to be_nil
    end

    it "serves crests from the CDN when CREST_BASE_URL is set" do
      stub_const("App::CREST_BASE_URL", "https://cdn.example.com/football-supporters")

      expect(helpers.crest_url("wsl/1075419-London City Lionesses.png"))
        .to eq("https://cdn.example.com/football-supporters/wsl/1075419-London%20City%20Lionesses.png")
    end

    it "encodes each path segment without escaping the separator" do
      stub_const("App::CREST_BASE_URL", "https://cdn.example.com")

      expect(helpers.crest_url("wsl/1075419-London City Lionesses.png"))
        .to eq("https://cdn.example.com/wsl/1075419-London%20City%20Lionesses.png")
    end

    # The CDN's keys are NFD; seed.rb and the files on disk are NFC. "ñ" is one
    # codepoint composed (C3 B1) and two decomposed (n + U+0303 -> 6E CC 83), so
    # the wrong form is a different object key and a 403.
    it "decomposes accented names to NFD for the CDN, which stores them that way" do
      stub_const("App::CREST_BASE_URL", "https://cdn.example.com")

      expect(helpers.crest_url("la-liga/9783-Deportivo A Coruña.png".unicode_normalize(:nfc)))
        .to eq("https://cdn.example.com/la-liga/9783-Deportivo%20A%20Corun%CC%83a.png")
    end

    it "leaves accented names composed for the local public/images fallback" do
      stub_const("App::CREST_BASE_URL", "/images")

      expect(with_request.crest_url("bundesliga/8722-Köln.png".unicode_normalize(:nfc)))
        .to eq("http://example.org/images/bundesliga/8722-K%C3%B6ln.png")
    end

    it "falls back to this host's public/images when CREST_BASE_URL is unset" do
      stub_const("App::CREST_BASE_URL", "/images")

      expect(with_request.crest_url("wsl/crest.png")).to eq("http://example.org/images/wsl/crest.png")
    end

    it "does not double up the separator when the base carries a trailing slash" do
      stub_const("App::CREST_BASE_URL", "https://cdn.example.com/crests/".chomp("/"))

      expect(helpers.crest_url("wsl/crest.png")).to eq("https://cdn.example.com/crests/wsl/crest.png")
    end
  end
end
