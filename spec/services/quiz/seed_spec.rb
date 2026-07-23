# frozen_string_literal: true

require "spec_helper"

RSpec.describe Quiz::Seed do
  # The suite seeds once in spec_helper; these assert the outcome and idempotency.
  it "creates the Premier League and its twenty clubs" do
    league = League.first(slug: "premier-league")

    expect(league).not_to be_nil
    expect(league.name).to eq("Premier League")
    expect(league.season).to eq("2026-27")
    expect(league.teams_dataset.count).to eq(20)
  end

  it "seeds each club's scores, blurb, and crest" do
    everton = Team.first(name: "Everton")

    expect(everton.vector).to eq([4.1, 2.0, 5.0, 8.0])
    expect(everton.crest).to eq("8668-Everton.png")
    expect(everton.blurb).to start_with("The People's Club")
  end

  it "is idempotent — re-running adds no rows" do
    expect { described_class.call }.not_to(change { [League.count, Team.count] })
  end

  it "upserts changed data back to the seed values" do
    everton = Team.first(name: "Everton")
    everton.update(blurb: "tampered")

    described_class.call

    expect(everton.refresh.blurb).to start_with("The People's Club")
    expect(Team.where(name: "Everton").count).to eq(1)
  end
end
