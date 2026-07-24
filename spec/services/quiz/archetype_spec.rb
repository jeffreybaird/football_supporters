# frozen_string_literal: true

require "spec_helper"

RSpec.describe Quiz::Archetype do
  # AXES order: [Vibe, Play, Ethics, Fanbase].
  def label(vec) = described_class.call(vec)[:label]
  def sentence(vec) = described_class.call(vec)[:sentence]

  it "returns The All-Rounder with the neutral sentence for a nil or malformed vector" do
    expect(label(nil)).to eq("The All-Rounder")
    expect(sentence(nil)).to eq(described_class::ALL_MID_SENTENCE)
    expect(label([1, 2, 3])).to eq("The All-Rounder")
  end

  it "selects the archetype whose centroid is nearest the given vector" do
    expect(label([6.33, 7.14, 6.24, 6.14])).to eq("The Dreamer")   # HHHH exactly
    expect(label([6.4, 7.2, 6.3, 6.2])).to eq("The Dreamer")       # near HHHH
    expect(label([4.14, 5.00, 2.00, 4.07])).to eq("The Stoic")     # LLLL exactly
  end

  it "ignores axis weighting and only responds to the raw vector" do
    ultra = [6.33, 7.14, 2.00, 6.14] # HHLH centroid
    expect(label(ultra)).to eq("The Ultra")
  end

  it "returns the label and sentence for every archetype code" do
    described_class::ARCHETYPES.each_value do |row|
      result = described_class.call(row["vec"])
      expect(result[:label]).to eq(row["label"])
      expect(result[:sentence]).to eq(row["sentence"])
    end
  end

  it "exposes the client table with all keys the browser algorithm needs" do
    t = described_class.client_table
    expect(t.keys).to contain_exactly("levels", "archetypes", "allMidLabel", "allMidSentence")
    expect(t["levels"]).to eq(described_class::LEVELS)
    expect(t["archetypes"]).to eq(described_class::ARCHETYPES)
  end
end
