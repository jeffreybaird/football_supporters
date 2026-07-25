# frozen_string_literal: true

require "spec_helper"

RSpec.describe Quiz::ClientData do
  let(:league) { League.default }

  it "ships the archetype table so the browser can rank and label archetypes" do
    payload = described_class.call(league)

    expect(payload["ARCHETYPE"]).to eq(Quiz::Archetype.client_table)
    expect(payload["ARCHETYPE"]["archetypes"]).to all(satisfy { |_code, row| row["vec"].length == 4 })
  end

  it "ships the archetype table even with no league (league-agnostic)" do
    expect(described_class.call(nil)["ARCHETYPE"]).to eq(Quiz::Archetype.client_table)
  end
end
