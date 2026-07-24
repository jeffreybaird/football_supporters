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

  it "creates the Bundesliga and its eighteen clubs behind the default league" do
    league = League.first(slug: "bundesliga")

    expect(league).not_to be_nil
    expect(league.name).to eq("Bundesliga")
    expect(league.teams_dataset.count).to eq(18)
    expect(league.position).to eq(1)
    expect(League.default.slug).to eq("premier-league")
  end

  it "seeds Bundesliga scores from the CSV, with no crest yet" do
    union = Team.first(league_id: League.first(slug: "bundesliga").id, name: "Union Berlin")

    expect(union.vector).to eq([2.0, 2.0, 10.0, 10.0])
    expect(union.crest).to be_nil
    expect(union.blurb).not_to be_empty
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
