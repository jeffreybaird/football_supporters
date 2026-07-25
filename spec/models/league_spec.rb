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

  describe "scoring params" do
    it "seeds the reference league with the Quiz::Data defaults" do
      league = League.default

      expect(league.chooser_threshold).to eq(Quiz::Data::CHOOSER_THRESHOLD)
      expect(league.max_choices).to eq(Quiz::Data::MAX_CHOICES)
      expect(league.amplify).to eq(Quiz::Data::AMPLIFY)
    end

    it "exposes scoring_params keyword-ready for Quiz::Score.call" do
      expect(League.default.scoring_params).to eq(
        chooser_threshold: Quiz::Data::CHOOSER_THRESHOLD,
        max_choices: Quiz::Data::MAX_CHOICES,
        amplify: Quiz::Data::AMPLIFY
      )
    end

    it "gives new leagues the column defaults" do
      league = League.create(slug: "new-liga", name: "New Liga")

      expect(league.chooser_threshold).to eq(0.25)
      expect(league.max_choices).to eq(3)
      expect(league.amplify).to eq(2.5)
    end

    it "rejects out-of-range scoring params" do
      expect(League.new(slug: "a", name: "A", chooser_threshold: -0.1)).not_to be_valid
      expect(League.new(slug: "b", name: "B", max_choices: 0)).not_to be_valid
      expect(League.new(slug: "c", name: "C", amplify: -1.0)).not_to be_valid
    end
  end
end
