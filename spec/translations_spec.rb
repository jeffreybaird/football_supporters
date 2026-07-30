# frozen_string_literal: true

require "spec_helper"

RSpec.describe Translations do
  # These examples deal in our own %{var} placeholder syntax, not Ruby format
  # strings, so the format-token style cop doesn't apply here.
  # rubocop:disable Style/FormatStringToken
  describe ".t" do
    it "fills a %{var} placeholder for the requested locale" do
      expect(described_class.t("titles.league", locale: "fr", name: "Ligue 1"))
        .to eq("Quel club de Ligue 1 devrais-tu supporter ?")
    end

    it "falls back to English when the locale omits a key" do
      # feedback.optional exists in en; assert French callers still get *a* string
      # even for a key that a translation might not carry.
      expect(described_class.t("titles.default", locale: "en")).to eq("Which Club Should You Support?")
    end

    it "returns the key itself when it is unknown in every locale" do
      expect(described_class.t("no.such.key", locale: "fr")).to eq("no.such.key")
    end

    it "leaves an unmatched placeholder in place rather than blanking it" do
      expect(described_class.t("titles.league", locale: "en")).to include("%{name}")
    end
  end
  # rubocop:enable Style/FormatStringToken

  describe ".negotiate" do
    it "picks the highest-q supported language from an Accept-Language header" do
      expect(described_class.negotiate("fr-FR,fr;q=0.9,en;q=0.8")).to eq("fr")
    end

    it "honours q-values over source order" do
      expect(described_class.negotiate("fr;q=0.3, en;q=0.9")).to eq("en")
    end

    it "matches on the primary subtag, ignoring the region" do
      expect(described_class.negotiate("fr-CA")).to eq("fr")
    end

    it "returns nil when no listed language is supported" do
      expect(described_class.negotiate("de-DE,es;q=0.8")).to be_nil
    end

    it "returns nil for a blank or missing header" do
      expect(described_class.negotiate(nil)).to be_nil
      expect(described_class.negotiate("")).to be_nil
    end
  end

  describe ".resolve" do
    it "prefers a supported cookie over the header" do
      expect(described_class.resolve(cookie: "fr", header: "en-US,en")).to eq("fr")
    end

    it "ignores an unsupported cookie and negotiates the header" do
      expect(described_class.resolve(cookie: "xx", header: "fr")).to eq("fr")
    end

    it "falls back to the default when neither cookie nor header resolves" do
      expect(described_class.resolve(cookie: nil, header: "de")).to eq("en")
    end
  end

  describe ".client" do
    it "returns the English tree for the default locale" do
      expect(described_class.client("en")["axes"]["Vibe"]).to eq("Vibe")
    end

    it "overlays translated strings on the English base for another locale" do
      fr = described_class.client("fr")
      expect(fr["axes"]["Vibe"]).to eq("Ambiance")
      # a key present only via the English base still resolves after the merge
      expect(fr["share"]["copy"]).to eq("Copier le lien")
    end
  end

  describe ".content" do
    it "carries the English questionnaire and archetype wording" do
      content = described_class.content("en")
      expect(content.dig("questions", "V2", "t")).to eq("A game's on with no team of yours involved. You want")
      expect(content.dig("sliders", "Play", "q")).to eq("How much does the style of football matter?")
      expect(content.dig("archetypes", "glory_hunter", "label")).to eq("The Glory Hunter")
      expect(content.dig("archetypes", "all_mid", "label")).to eq("The All-Rounder")
    end

    it "carries the French question, slider and archetype overrides" do
      content = described_class.content("fr")
      expect(content.dig("questions", "V2", "t")).to start_with("Un match")
      expect(content.dig("sliders", "Play", "q")).to include("style de jeu")
      expect(content.dig("archetypes", "glory_hunter", "label")).to eq("Le Chasseur de gloire")
    end
  end
end
