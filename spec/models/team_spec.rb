# frozen_string_literal: true

require "spec_helper"

RSpec.describe Team do
  let(:league) { League.default }

  def team(name) = league.scored_teams.find { |t| t.name == name }

  it "returns its vector in axis order" do
    expect(team("Man City").vector).to eq([10.0, 5.0, 2.0, 3.0])
  end

  it "requires a league, name, blurb, and all four scores" do
    expect(Team.new(league_id: league.id, name: "Nameless")).not_to be_valid
  end

  it "rejects scores outside 0..10" do
    over = Team.new(league_id: league.id, name: "Over", vibe: 11, play: 5, ethics: 5, fanbase: 5, blurb: "b")
    expect(over).not_to be_valid
  end

  it "enforces club-name uniqueness within a league" do
    dupe = Team.new(league_id: league.id, name: "Everton", vibe: 1, play: 1, ethics: 1, fanbase: 1, blurb: "b")
    expect(dupe).not_to be_valid
  end

  it "allows the same club name in a different league" do
    other = League.create(slug: "other", name: "Other")
    twin = Team.new(league_id: other.id, name: "Everton", vibe: 1, play: 1, ethics: 1, fanbase: 1, blurb: "b")
    expect(twin).to be_valid
  end

  it "defaults popularity to 1.0 (unweighted) when unseeded" do
    other = League.create(slug: "other", name: "Other")
    plain = Team.create(league_id: other.id, name: "Anon", vibe: 5, play: 5, ethics: 5, fanbase: 5, blurb: "b")
    expect(plain.popularity).to eq(1.0)
  end

  it "seeds the reference league's per-club popularity for the aligned target" do
    expect(team("Man United").popularity).to eq(100.0)
    expect(team("Leeds").popularity).to eq(18.0)
  end

  it "rejects a negative popularity (it is raised to a fractional power)" do
    bad = Team.new(league_id: league.id, name: "Neg", vibe: 5, play: 5, ethics: 5, fanbase: 5,
                   blurb: "b", popularity: -1.0)
    expect(bad).not_to be_valid
  end
end
