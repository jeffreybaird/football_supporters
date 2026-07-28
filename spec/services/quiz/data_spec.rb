# frozen_string_literal: true

require "spec_helper"

RSpec.describe Quiz::Data do
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
