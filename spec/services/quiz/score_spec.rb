# frozen_string_literal: true

require "spec_helper"

RSpec.describe Quiz::Score do
  # Values below are pinned reference outputs of this scorer, re-derived after the
  # matcher moved from centroid+amplify to distribution alignment (Quiz::Score
  # standardises the user vector against Quiz::Data::USER_MEAN/USER_SD and re-places
  # it in the popularity-weighted team target). The axis vector (score_axes) is
  # unchanged by that move, so the vec pins hold; the picks, candidates and gaps
  # shifted deliberately and are the new contract. Retune together with USER_MEAN/
  # USER_SD, POPULARITY_ALPHA or the seeded popularity.
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

    expect(r.pick.name).to eq("Man United")
    expect(r.candidates.map(&:name)).to eq(["Man United"])
    expect(rounded(r.vec)).to eq([6.3396, 4.5946, 10.0, 7.3524])
    expect(r.gap.round(4)).to eq(0.6884)
  end

  it "matches the reference scorer for the all-last-option answer set" do
    r = described_class.call(teams:, answers: Array.new(13, 3), weights: [5, 5, 5, 5])

    expect(r.pick.name).to eq("Chelsea")
    expect(r.candidates.map(&:name)).to eq(["Chelsea", "Man City"])
    expect(rounded(r.vec)).to eq([5.5094, 6.8919, 1.0, 3.0571])
  end

  it "matches the reference scorer for a mixed answer set" do
    answers = [1, 2, 0, 3, 1, 2, 3, 0, 1, 2, 3, 0, 1]
    r = described_class.call(teams:, answers:, weights: [5, 5, 5, 5])

    expect(r.pick.name).to eq("Arsenal")
    expect(r.candidates.map(&:name)).to eq(["Arsenal"])
    expect(rounded(r.vec)).to eq([5.8868, 6.3784, 7.8824, 4.981])
    expect(r.gap.round(4)).to eq(0.419)
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

  it "applies a per-call alpha when ranking" do
    answers = Array.new(13, 0)
    fit = described_class.call(teams:, answers:, weights: [5, 5, 5, 5], alpha: 0.0)
    pop = described_class.call(teams:, answers:, weights: [5, 5, 5, 5], alpha: 1.0)

    # vec is transform-independent; the ranking distances shift with the target.
    expect(rounded(fit.vec)).to eq(rounded(pop.vec))
    expect(fit.rank.first.dist).not_to eq(pop.rank.first.dist)
  end

  it "leans the matching target toward popular clubs as alpha rises" do
    fit = described_class.target_of(teams, 0.0) # unweighted coordinate distribution
    pop = described_class.target_of(teams, 1.0) # popularity-weighted

    # EPL's most-supported clubs are its high-Vibe giants, so trusting popularity
    # pulls the Vibe target upward.
    expect(pop[:mean][0]).to be > fit[:mean][0]
    expect(fit[:mean].length).to eq(4)
    expect(fit[:sd].length).to eq(4)
  end

  it "derives match from the raw (pre-alignment) distance, so match% is alpha-independent" do
    answers = Array.new(13, 0)
    fit = described_class.call(teams:, answers:, weights: [5, 5, 5, 5], alpha: 0.0)
    pop = described_class.call(teams:, answers:, weights: [5, 5, 5, 5], alpha: 1.0)

    fit_match = fit.rank.to_h { |r| [r.name, r.match] }
    pop_match = pop.rank.to_h { |r| [r.name, r.match] }
    fit_match.each { |name, m| expect(m).to be_within(1e-9).of(pop_match[name]) }

    # match is 1 - raw_dist/DIAMETER over the RAW user vector (equal weights here),
    # independent of the alignment used for ranking.
    w = [0.25, 0.25, 0.25, 0.25]
    fit.rank.each do |r|
      raw = Math.sqrt(w.each_index.sum { |k| w[k] * ((fit.vec[k] - r.team.vector[k])**2) })
      expect(r.match).to be_within(1e-9).of(1.0 - (raw / Quiz::Score::DIAMETER))
      expect(r.match).to be_between(0.0, 1.0)
    end
  end
end
