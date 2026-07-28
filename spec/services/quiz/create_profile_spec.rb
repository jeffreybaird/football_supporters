# frozen_string_literal: true

require "spec_helper"

RSpec.describe Quiz::CreateProfile do
  let(:valid_answers) { Array.new(13, 0) }
  let(:valid_weights) { [5, 5, 5, 5] }

  def call(attrs) = described_class.call(attrs:)

  it "persists a profile: league-less, flagged, archetype label in pick" do
    result = call("answers" => valid_answers, "weights" => valid_weights)

    expect(result).to be_success
    record = result.value!
    expect(record.profile?).to be(true)
    expect(record.league_id).to be_nil
    expect(record.pick).to eq(Quiz::Archetype.call(Quiz::Score.score_axes(valid_answers))[:label])
    # Stored as a question-id -> option-index map (see AnswerValidation), not a
    # positional array.
    expect(record.answers).to eq(Quiz::Data::Q.to_h { |q| [q["id"], 0] })
    expect(record.weights).to eq(valid_weights)
  end

  it "stores the caller's fingerprint" do
    record = described_class.call(attrs: { "answers" => valid_answers, "weights" => valid_weights },
                                  fingerprint: "fp-profile").value!

    expect(record.fingerprint).to eq("fp-profile")
  end

  it "links each league's winning club through the join table" do
    profile = Quiz::ProfileScore.call(answers: valid_answers, weights: valid_weights)
    record = call("answers" => valid_answers, "weights" => valid_weights).value!

    expect(record.teams.map(&:id)).to match_array(profile.leagues.map { |e| e.pick.id })
  end

  it "mints a distinct slug per profile" do
    a = call("answers" => valid_answers, "weights" => valid_weights).value!
    b = call("answers" => valid_answers, "weights" => valid_weights).value!

    expect(a.slug).not_to eq(b.slug)
  end

  it "fails validation for a malformed answer set" do
    result = call("answers" => [0, 1], "weights" => valid_weights)

    expect(result).to be_failure
    expect(result.failure.first).to eq(:validation)
    expect(QuizResult.count).to eq(0)
  end

  it "fails validation for out-of-range weights" do
    result = call("answers" => valid_answers, "weights" => [0, 5, 5, 5])

    expect(result).to be_failure
    expect(result.failure.first).to eq(:validation)
  end
end
