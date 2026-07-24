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

  def centroid(code) = described_class::ARCHETYPES.fetch(code)["vec"]

  it "selects the archetype whose centroid is nearest the given vector" do
    expect(label(centroid("HHHH"))).to eq("The Dreamer")
    expect(label(centroid("LLLL"))).to eq("The Stoic")
    # A vector nudged a hair off a centroid still resolves to that archetype.
    near = centroid("HHHH").map { |x| x + 0.05 }
    expect(label(near)).to eq("The Dreamer")
  end

  it "maps every archetype's own centroid to itself even under lopsided weighting" do
    described_class::ARCHETYPES.each_value do |row|
      expect(described_class.call(row["vec"], weights: [10, 1, 1, 10])[:label]).to eq(row["label"])
    end
  end

  # The centroids are scattered off the per-axis lattice (see Archetype's header
  # comment), so — exactly like club selection — reweighting an axis can change
  # the #1 archetype, not merely re-sort the tail. This pins that the leader
  # actually moves with the sliders.
  it "lets slider weights change the winning archetype, like club selection" do
    vec = [4.5, 5.5, 3.0, 5.0]
    winners = [[5, 5, 5, 5], [9, 3, 3, 3], [3, 3, 9, 3], [3, 3, 3, 9]].map do |w|
      described_class.call(vec, weights: w)[:label]
    end
    expect(winners.uniq.size).to be > 1
  end

  describe ".weight_vector" do
    it "normalises valid weights to sum to 1" do
      expect(described_class.weight_vector([1, 1, 1, 1])).to eq([0.25, 0.25, 0.25, 0.25])
      expect(described_class.weight_vector([2, 0, 0, 2])).to eq([0.5, 0.0, 0.0, 0.5])
    end

    it "falls back to equal weighting for nil, wrong arity, non-numeric or all-zero" do
      equal = described_class::EQUAL_WEIGHTS
      expect(described_class.weight_vector(nil)).to eq(equal)
      expect(described_class.weight_vector([1, 2, 3])).to eq(equal)
      expect(described_class.weight_vector([1, 2, "x", 4])).to eq(equal)
      expect(described_class.weight_vector([0, 0, 0, 0])).to eq(equal)
    end
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
