# frozen_string_literal: true

require "spec_helper"

RSpec.describe Quiz::Data do
  # The canonical questionnaire order. Stored answers (and the client's answer
  # array) are indexed against this, so reordering the per-question skeleton files
  # would silently misread historical results — pin it.
  let(:canonical_order) { %w[V2 V4 V10 P1 P3 P5 P8 E2 E3 F3 F4 F5 F7] }

  describe "the scoring skeleton (config/quiz/questions/*.yml)" do
    it "loads every question once, in the canonical order" do
      expect(described_class::SKELETON.map { |q| q["id"] }).to eq(canonical_order)
    end

    it "carries a 4-axis loading and a 4-value vector per option, no text" do
      described_class::SKELETON.each do |skeleton|
        expect(skeleton["load"].length).to eq(4)
        expect(skeleton["options"]).to all(satisfy { |v| v.length == 4 })
        expect(skeleton).not_to have_key("t")
      end
    end
  end

  describe "skeleton/wording alignment" do
    it "has wording for every skeleton question and option in each locale" do
      Translations::SUPPORTED.each do |locale|
        localized = described_class.questions(locale)
        expect(localized.map { |q| q["id"] }).to eq(canonical_order)
        described_class::SKELETON.each_with_index do |skeleton, i|
          labels = localized[i]["a"].map { |opt| opt["l"] }
          expect(labels.length).to eq(skeleton["options"].length)
          expect(labels).to all(be_a(String))
          expect(localized[i]["t"]).to be_a(String)
        end
      end
    end
  end

  describe ".questions" do
    it "returns the canonical English questionnaire unchanged for the default locale" do
      expect(described_class.questions).to eq(described_class::Q)
      expect(described_class.questions("en")).to eq(described_class::Q)
    end

    it "localizes the question and answer text for a translated locale" do
      fr = described_class.questions("fr")
      v2 = fr.find { |q| q["id"] == "V2" }

      expect(v2["t"]).to eq("Un match sans aucune de tes équipes. Tu veux")
      expect(v2["a"].map { |opt| opt["l"] }).to include("que le petit crée la surprise")
    end

    it "never touches the numeric loadings or option values (client/server score alike)" do
      canonical = described_class::Q.find { |q| q["id"] == "V2" }
      fr = described_class.questions("fr").find { |q| q["id"] == "V2" }

      expect(fr["load"]).to eq(canonical["load"])
      expect(fr["a"].map { |opt| opt["v"] }).to eq(canonical["a"].map { |opt| opt["v"] })
    end

    it "translates every question and every option (nothing left in English)" do
      fr = described_class.questions("fr")

      described_class::Q.each_with_index do |canonical, i|
        localized = fr[i]
        expect(localized["t"]).not_to eq(canonical["t"])
        canonical["a"].each_with_index do |opt, j|
          expect(localized["a"][j]["l"]).not_to eq(opt["l"])
        end
      end
    end
  end

  describe ".sliders" do
    it "returns the canonical English sliders unchanged for the default locale" do
      expect(described_class.sliders).to eq(described_class::SLIDERS)
    end

    it "localizes the slider prompts and endpoints, keeping the axis key" do
      fr = described_class.sliders("fr")
      play = fr.find { |s| s["ax"] == "Play" }

      expect(play["ax"]).to eq("Play")
      expect(play["q"]).to eq("Quelle importance a le style de jeu ?")
      expect(play["lo"]).to eq("Aucune importance")
      expect(play["hi"]).to eq("Beaucoup d'importance")
    end
  end
end
