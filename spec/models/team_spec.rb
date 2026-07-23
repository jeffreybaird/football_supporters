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
end
