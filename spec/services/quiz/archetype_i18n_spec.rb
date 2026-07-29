# frozen_string_literal: true

require "spec_helper"

# Localization of the archetype copy. The numeric model (levels, cells, scatter,
# selection) is language-independent and covered by archetype_spec; here we only
# assert the label/sentence text swaps with the locale while the model does not.
RSpec.describe Quiz::Archetype do
  # A vector that lands on a known archetype under equal weights, reused so the
  # English and French assertions describe the same pick.
  let(:vec) { [6.33, 7.14, 6.24, 6.14] }

  describe ".call" do
    it "returns English copy by default" do
      result = described_class.call(vec)
      expect(result[:label]).to eq("The Weekend Giant")
    end

    it "returns French copy for the fr locale, for the same pick" do
      expect(described_class.call(vec, locale: "fr")[:label]).to eq("Le Géant du week-end")
    end

    it "localizes the all-mid fallback (unscoreable vector) too" do
      expect(described_class.call([1, 2], locale: "fr")[:label]).to eq("Le Polyvalent")
      expect(described_class.call([1, 2], locale: "en")[:label]).to eq("The All-Rounder")
    end
  end

  describe ".client_table" do
    it "is unchanged (English) for the default locale" do
      expect(described_class.client_table).to eq(described_class.client_table("en"))
      expect(described_class.client_table["archetypes"][:glory_hunter]["label"]).to eq("The Glory Hunter")
    end

    it "swaps in the translated labels/sentences for another locale" do
      table = described_class.client_table("fr")
      expect(table["archetypes"][:glory_hunter]["label"]).to eq("Le Chasseur de gloire")
      expect(table["allMidLabel"]).to eq("Le Polyvalent")
    end

    it "keeps the numeric model identical across locales so centroids can't drift" do
      en = described_class.client_table("en")
      fr = described_class.client_table("fr")

      expect(fr["levels"]).to eq(en["levels"])
      expect(fr["cells"]).to eq(en["cells"])
      expect(fr["scatter"]).to eq(en["scatter"])
    end
  end

  describe "translation coverage" do
    it "provides a French label and sentence for every archetype and the all-mid fallback" do
      fr = Translations.content("fr")["archetypes"]
      ids = described_class::ARCHETYPES.keys.map(&:to_s) + ["all_mid"]

      ids.each do |id|
        expect(fr[id]).to include("label", "sentence"), "missing French copy for #{id}"
        expect(fr.dig(id, "label")).not_to be_empty
      end
    end
  end
end
