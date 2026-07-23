# frozen_string_literal: true

require "spec_helper"

RSpec.describe Quiz::Score do
  # Values below are pinned against the original browser scorer — a Node replay of
  # the source agreed with this port on 712 random cases (vector, full ranking,
  # candidates and gap to 1e-9). The seeded Premier League teams carry the same
  # coordinates in the same order, so the pins still hold after the DB refactor.
  let(:teams) { League.default.scored_teams }

  def rounded(vec) = vec.map { |x| x.round(4) }

  it "ranks every club, best first" do
    r = described_class.call(teams:, answers: Array.new(13, 0), weights: [5, 5, 5, 5])

    expect(r.rank.length).to eq(teams.length)
    sims = r.rank.map(&:sim)
    expect(sims).to eq(sims.sort.reverse)
    expect(r.pick).to eq(r.rank.first.team)
    expect(r.candidates.first).to eq(r.pick)
  end

  it "matches the reference scorer for the all-first-option answer set" do
    r = described_class.call(teams:, answers: Array.new(13, 0), weights: [5, 5, 5, 5])

    expect(r.pick.name).to eq("Everton")
    expect(r.candidates.map(&:name)).to eq(["Everton"])
    expect(rounded(r.vec)).to eq([6.0351, 4.5946, 10.0, 7.61])
    expect(r.gap.round(4)).to eq(0.2922)
  end

  it "matches the reference scorer for the all-last-option answer set" do
    r = described_class.call(teams:, answers: Array.new(13, 3), weights: [5, 5, 5, 5])

    expect(r.pick.name).to eq("Chelsea")
    expect(r.candidates.map(&:name)).to eq(["Chelsea", "Man City"])
    expect(rounded(r.vec)).to eq([5.6842, 6.8919, 1.0, 2.66])
  end

  it "matches the reference scorer for a mixed answer set" do
    answers = [1, 2, 0, 3, 1, 2, 3, 0, 1, 2, 3, 0, 1]
    r = described_class.call(teams:, answers:, weights: [5, 5, 5, 5])

    expect(r.pick.name).to eq("Liverpool")
    expect(r.candidates.map(&:name)).to eq(["Liverpool", "Crystal Palace"])
    expect(rounded(r.vec)).to eq([5.614, 6.3784, 7.8824, 5.09])
    expect(r.gap.round(4)).to eq(0.1847)
  end

  it "defaults every axis with no evidence to 5.0" do
    r = described_class.call(teams:, answers: Array.new(13, nil), weights: [5, 5, 5, 5])

    expect(r.vec).to eq([5.0, 5.0, 5.0, 5.0])
  end

  it "offers at most MAX_CHOICES candidates, all within the chooser threshold" do
    r = described_class.call(teams:, answers: Array.new(13, 3), weights: [5, 5, 5, 5])

    expect(r.candidates.length).to be <= Quiz::Data::MAX_CHOICES
    r.candidates.drop(1).each do |team|
      ranked = r.rank.find { |x| x.team == team }
      expect(ranked.dist - r.rank.first.dist).to be < Quiz::Data::CHOOSER_THRESHOLD
    end
  end

  it "caps candidates at a per-call max_choices" do
    answers = Array.new(13, 3) # default offers ["Chelsea", "Man City"]
    r = described_class.call(teams:, answers:, weights: [5, 5, 5, 5], max_choices: 1)

    expect(r.candidates.map(&:name)).to eq(["Chelsea"])
  end

  it "widens the alternates with a larger chooser_threshold" do
    answers = Array.new(13, 3)
    r = described_class.call(teams:, answers:, weights: [5, 5, 5, 5], chooser_threshold: 100.0, max_choices: 5)

    expect(r.candidates.length).to eq(5)
    expect(r.candidates.map(&:name)).to eq(r.rank.first(5).map(&:name))
  end

  it "applies a per-call amplify when ranking" do
    answers = Array.new(13, 0)
    tight = described_class.call(teams:, answers:, weights: [5, 5, 5, 5], amplify: 1.0)
    wide  = described_class.call(teams:, answers:, weights: [5, 5, 5, 5], amplify: 2.5)

    # vec is amplify-independent; the ranking distances are not.
    expect(rounded(tight.vec)).to eq(rounded(wide.vec))
    expect(tight.rank.first.dist).not_to eq(wide.rank.first.dist)
  end
end
