# frozen_string_literal: true

require "spec_helper"

RSpec.describe League do
  describe ".default" do
    it "returns the seeded Premier League" do
      expect(League.default.slug).to eq("premier-league")
    end

    it "ignores inactive leagues even at a lower position" do
      League.create(slug: "test-liga", name: "Test", active: false, position: -10)

      expect(League.default.slug).to eq("premier-league")
    end
  end

  describe "#scored_teams" do
    it "returns the league's kept teams in position order" do
      teams = League.default.scored_teams

      expect(teams.length).to eq(20)
      expect(teams.first.name).to eq("Man City")
      expect(teams.map(&:position)).to eq(teams.map(&:position).sort)
    end

    it "excludes soft-deleted teams" do
      League.default.scored_teams.first.soft_delete!

      expect(League.default.scored_teams.length).to eq(19)
    end
  end

  it "enforces slug uniqueness" do
    expect(League.new(slug: "premier-league", name: "Dup")).not_to be_valid
  end

  it "requires slug and name" do
    expect(League.new(slug: nil, name: "X")).not_to be_valid
    expect(League.new(slug: "x", name: nil)).not_to be_valid
  end
end
