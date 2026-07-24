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
end
