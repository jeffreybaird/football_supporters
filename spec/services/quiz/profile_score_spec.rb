# frozen_string_literal: true

require "spec_helper"

RSpec.describe Quiz::ProfileScore do
  let(:answers) { Array.new(13, 0) }
  let(:weights) { [5, 5, 5, 5] }

  subject(:result) { described_class.call(answers:, weights:) }

  it "derives the vector and archetype from the shared league-independent scorer" do
    expect(result.vec).to eq(Quiz::Score.score_axes(answers))
    expect(result.archetype).to eq(Quiz::Archetype.call(result.vec))
  end

  it "returns one entry per active scorable league, ordered" do
    expect(result.leagues.map { |e| e.league.slug }).to eq(
      League.active.ordered.all.select { |l| l.scored_teams.any? }.map(&:slug)
    )
  end

  it "picks each league's winner via the same per-league scorer, with match_pct = round((1 - d_raw/10)*100)" do
    result.leagues.each do |entry|
      top = Quiz::Score.call(teams: entry.league.scored_teams, answers:, weights:, **entry.league.scoring_params).rank.first
      expect(entry.pick.name).to eq(top.team.name)
      expect(entry.sim).to be_within(1e-9).of(top.sim)
      # match_pct is the linear raw-distance closeness, NOT the steep ranking sim.
      expect(entry.match_pct).to eq((top.match * 100).round)
      expect(entry.match_pct).to be_between(0, 100)
    end
  end
end
