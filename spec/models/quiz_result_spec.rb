# frozen_string_literal: true

require "spec_helper"

RSpec.describe QuizResult do
  def build_result(**overrides)
    QuizResult.new(
      { slug: "abc123", answers: Array.new(13, 0), weights: [5, 5, 5, 5], pick: "Everton" }.merge(overrides)
    )
  end

  it "round-trips answers and weights as JSON" do
    record = build_result.tap(&:save)
    reloaded = QuizResult.first(id: record.id)

    expect(reloaded.answers).to eq(Array.new(13, 0))
    expect(reloaded.weights).to eq([5, 5, 5, 5])
  end

  it "belongs to a league" do
    league = League.default
    record = build_result(league_id: league.id).tap(&:save)

    expect(record.league).to eq(league)
  end

  it "defaults profile to false and marks profile rows" do
    expect(build_result.tap(&:save).profile?).to be(false)

    profile = build_result(slug: "prof1", profile: true, league_id: nil, pick: "The Glory Hunter")
    expect(profile).to be_valid
    profile.save_changes
    expect(profile.profile?).to be(true)
  end

  it "requires slug and pick" do
    expect(build_result(slug: nil)).not_to be_valid
    expect(build_result(pick: nil)).not_to be_valid
  end

  it "enforces slug uniqueness" do
    build_result(slug: "dup").save_changes
    dupe = build_result(slug: "dup")

    expect(dupe).not_to be_valid
  end

  it "links the clubs it returned through the join table" do
    record = build_result(slug: "linked").tap(&:save)
    team = League.default.scored_teams.first

    record.add_team(team)

    expect(QuizResult.first(id: record.id).teams.map(&:id)).to eq([team.id])
    expect(team.quiz_results.map(&:id)).to include(record.id)
  end

  describe ".kept" do
    it "excludes soft-deleted rows" do
      live = build_result(slug: "live").tap(&:save)
      gone = build_result(slug: "gone").tap(&:save)
      gone.soft_delete!

      slugs = QuizResult.kept.all.map(&:slug)
      expect(slugs).to include(live.slug)
      expect(slugs).not_to include(gone.slug)
    end
  end
end
