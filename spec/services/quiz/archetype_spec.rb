# frozen_string_literal: true

require "spec_helper"

RSpec.describe Quiz::Archetype do
  # AXES order: [Vibe, Play, Ethics, Fanbase].
  def label(vec) = described_class.call(vec)[:label]
  def sentence(vec) = described_class.call(vec)[:sentence]

  it "returns The All-Rounder with the neutral sentence when every axis is mid" do
    expect(label([5, 5, 5, 5])).to eq("The All-Rounder")
    expect(sentence([5, 5, 5, 5])).to eq(described_class::ALL_MID_SENTENCE)
  end

  it "labels by the dominant (furthest-from-5) axis and direction" do
    expect(label([9, 5, 5, 5])).to eq("The Glory-Hunter")   # Vibe high
    expect(label([5, 1, 5, 5])).to eq("The Purist")         # Play low
    expect(label([5, 5, 9, 5])).to eq("The Idealist")       # Ethics high
    expect(label([5, 5, 5, 10])).to eq("The Ultra")         # Fanbase high (belonging)
    expect(label([5, 5, 5, 1])).to eq("The Neutral")        # Fanbase low
  end

  it "treats the band edges as inclusive (<=3.5 low, >=6.5 high)" do
    expect(label([3.5, 5, 5, 5])).to eq("The Romantic")      # exactly low
    expect(label([6.5, 5, 5, 5])).to eq("The Glory-Hunter")  # exactly high
    expect(label([3.6, 5, 5, 5])).to eq("The All-Rounder")   # just inside mid
  end

  it "breaks ties by axis order (Vibe, Play, Ethics, Fanbase)" do
    # Vibe and Play equally far from 5 (both +3) — Vibe wins.
    expect(label([8, 8, 5, 5])).to eq("The Glory-Hunter")
  end

  it "builds the sentence from the two strongest non-mid axes" do
    s = sentence([9, 5, 5, 1]) # Vibe high + Fanbase low, both |4|
    expect(s).to start_with("This is the kind of team you want:")
    expect(s).to include(described_class::FRAGMENTS["Vibe"]["high"])
    expect(s).to include(described_class::FRAGMENTS["Fanbase"]["low"])
    expect(s).to end_with(".")
  end

  it "uses a single fragment when only one axis is non-mid" do
    s = sentence([9, 5, 5, 5])
    expect(s).to include(described_class::FRAGMENTS["Vibe"]["high"])
    expect(s).not_to include(", and ")
  end

  it "exposes the client table with all keys the browser algorithm needs" do
    t = described_class.client_table
    expect(t.keys).to contain_exactly("bands", "labels", "fragments", "allMidLabel", "allMidSentence")
    expect(t["bands"]).to eq("low" => 3.5, "high" => 6.5)
  end
end
