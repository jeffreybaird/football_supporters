# frozen_string_literal: true

require "spec_helper"

RSpec.describe Quiz::ProfileData do
  subject(:payload) { described_class.call }

  it "hoists the league-agnostic keys once at the top level" do
    expect(payload["AXES"]).to eq(Quiz::Data::AXES)
    expect(payload["Q"]).to eq(Quiz::Data::Q)
    expect(payload["SLIDERS"]).to eq(Quiz::Data::SLIDERS)
    expect(payload["ARCHETYPE"]).to eq(Quiz::Archetype.client_table)
    expect(payload["ALPHA"]).to eq(Quiz::Data::POPULARITY_ALPHA)
    expect(payload["USER_MEAN"]).to eq(Quiz::Data::USER_MEAN)
    expect(payload["USER_SD"]).to eq(Quiz::Data::USER_SD)
  end

  it "includes one entry per active scorable league" do
    expect(payload["LEAGUES"].length).to eq(League.active.ordered.all.count { |l| l.scored_teams.any? })
    slugs = payload["LEAGUES"].map { |e| e["LEAGUE"]["slug"] }
    expect(slugs).to include("premier-league", "bundesliga", "ligue-1", "mls", "nwsl")
  end

  it "carries per-league keys but not the hoisted shared keys in each entry" do
    entry = payload["LEAGUES"].first
    expect(entry.keys).to include("LEAGUE", "TEAMS", "FLAVOR", "BADGE", "CHOOSER_THRESHOLD",
                                  "MAX_CHOICES", "POPULARITY")
    # ALPHA and the USER distribution are global scoring inputs, hoisted once.
    expect(entry.keys).not_to include("AXES", "Q", "SLIDERS", "ALPHA", "USER_MEAN", "USER_SD")
  end

  it "skips a league with no teams" do
    League.create(slug: "empty-liga", name: "Empty", position: 99)

    slugs = described_class.call["LEAGUES"].map { |e| e["LEAGUE"]["slug"] }
    expect(slugs).not_to include("empty-liga")
  end
end
