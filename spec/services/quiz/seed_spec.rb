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
    expect(everton.crest).to eq("premier-league/8668-Everton.png")
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

  it "seeds Bundesliga scores from the CSV, with a crest and blurb" do
    union = Team.first(league_id: League.first(slug: "bundesliga").id, name: "Union Berlin")

    expect(union.vector).to eq([2.0, 2.0, 10.0, 10.0])
    expect(union.crest).to eq("bundesliga/8149-Union_Berlin.png")
    expect(union.blurb).not_to be_empty
  end

  it "creates Ligue 1 with its eighteen clubs and per-league scoring tuning" do
    league = League.first(slug: "ligue-1")

    expect(league).not_to be_nil
    expect(league.name).to eq("Ligue 1")
    expect(league.teams_dataset.count).to eq(18)
    expect(league.amplify).to eq(1.7)
    expect(league.chooser_threshold).to eq(0.25)
  end

  it "seeds Ligue 1 scores, crest, and blurb from the CSV" do
    psg = Team.first(league_id: League.first(slug: "ligue-1").id, name: "Paris Saint-Germain")

    expect(psg.vector).to eq([10.0, 7.0, 0.0, 4.0])
    expect(psg.crest).to eq("ligue-1/9847-PSG.png")
    expect(psg.blurb).to start_with("For a decade PSG")
  end

  it "creates MLS with its thirty clubs and per-league scoring tuning" do
    league = League.first(slug: "mls")

    expect(league).not_to be_nil
    expect(league.name).to eq("MLS")
    expect(league.teams_dataset.count).to eq(30)
    expect(league.amplify).to eq(1.8)
    expect(league.chooser_threshold).to eq(0.20)
  end

  it "seeds MLS scores, a league-scoped crest, and a blurb" do
    miami = Team.first(league_id: League.first(slug: "mls").id, name: "Inter Miami")

    expect(miami.vector).to eq([10.0, 10.0, 3.0, 5.0])
    expect(miami.crest).to eq("mls/960720-Inter_Miami_CF.png")
    expect(miami.blurb).to start_with("The Messi circus")
  end

  it "creates NWSL with its sixteen clubs and per-league scoring tuning" do
    league = League.first(slug: "nwsl")

    expect(league).not_to be_nil
    expect(league.name).to eq("NWSL")
    expect(league.teams_dataset.count).to eq(16)
    expect(league.amplify).to eq(2.5)
    expect(league.chooser_threshold).to eq(0.25)
  end

  it "seeds NWSL scores, a league-scoped crest, and a blurb" do
    angel = Team.first(league_id: League.first(slug: "nwsl").id, name: "Angel City FC")

    expect(angel.vector).to eq([10.0, 6.0, 6.0, 8.0])
    expect(angel.crest).to eq("nwsl/1335914-Angel_City_FC.png")
    expect(angel.blurb).to start_with("Founded by Natalie Portman")
  end

  it "creates La Liga with its twenty clubs behind the earlier leagues" do
    league = League.first(slug: "la-liga")

    expect(league).not_to be_nil
    expect(league.name).to eq("La Liga")
    expect(league.season).to eq("2026-27")
    expect(league.teams_dataset.count).to eq(20)
    expect(league.amplify).to eq(1.6)
    expect(league.position).to eq(5)
  end

  it "seeds La Liga scores from the CSV, with a league-scoped crest and blurb" do
    madrid = Team.first(league_id: League.first(slug: "la-liga").id, name: "Real Madrid")

    expect(madrid.vector).to eq([10.0, 6.0, 5.0, 6.0])
    expect(madrid.crest).to eq("la-liga/8633-Real Madrid.png")
    expect(madrid.blurb).to start_with("The most successful club on earth")
  end

  it "honours each league's per-league amplify override" do
    expect(League.first(slug: "bundesliga").amplify).to eq(1.4)
    expect(League.first(slug: "premier-league").amplify).to eq(2.5)
  end

  # A crest is optional (the badge falls back to initials), but any crest that IS
  # set must resolve to a real file — a typo'd filename should fail the suite.
  it "points every seeded crest at a file that exists on disk" do
    Team.exclude(crest: nil).each do |team|
      expect(File.exist?(File.join("public/images", team.crest))).to be(true), "missing #{team.crest}"
    end
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
