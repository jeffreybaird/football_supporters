# frozen_string_literal: true

require "spec_helper"

RSpec.describe Quiz::ClientData do
  let(:league) { League.default }

  it "ships the archetype table so the browser can rank and label archetypes" do
    payload = described_class.call(league)

    expect(payload["ARCHETYPE"]).to eq(Quiz::Archetype.client_table)
    expect(payload["ARCHETYPE"]["archetypes"]).to all(satisfy { |_id, row| row["label"] && row["sentence"] })
    # The browser rebuilds the cell centroids from levels + cells + scatter, so
    # all three have to be on the wire (see cellVecs in views/quiz/index.erb).
    expect(payload["ARCHETYPE"]["cells"].size).to eq(81)
    expect(payload["ARCHETYPE"]["scatter"]).to be_a(Numeric)
  end

  it "ships the archetype table even with no league (league-agnostic)" do
    expect(described_class.call(nil)["ARCHETYPE"]).to eq(Quiz::Archetype.client_table)
  end
end
