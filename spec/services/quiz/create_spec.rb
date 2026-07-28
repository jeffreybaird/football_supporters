# frozen_string_literal: true

require "spec_helper"

RSpec.describe Quiz::Create do
  let(:league) { League.default }
  let(:valid_answers) { Array.new(13, 0) }
  let(:valid_weights) { [5, 5, 5, 5] }

  def create(attrs)
    described_class.call(league:, attrs:)
  end

  it "persists a completed quiz, resolves its club, and links the league" do
    result = create("answers" => valid_answers, "weights" => valid_weights)

    expect(result.success?).to be(true)
    record = result.value!
    expect(record.pick).to eq("Man United")
    expect(record.league_id).to eq(league.id)
    expect(record.slug).to be_a(String)
    expect(record.slug).not_to be_empty
    # Stored as a question-id -> option-index map, not a positional array, so a
    # stored answer stays bound to its question regardless of display order.
    expect(record.answers).to eq(Quiz::Data::Q.to_h { |q| [q["id"], 0] })
    expect(record.weights).to eq(valid_weights)
    expect(QuizResult.count).to eq(1)
  end

  it "accepts answers as a question-id -> option map and scores them the same" do
    as_map = Quiz::Data::Q.to_h { |q| [q["id"], 0] }
    from_map = create("answers" => as_map, "weights" => valid_weights).value!
    from_array = create("answers" => valid_answers, "weights" => valid_weights).value!

    expect(from_map.answers).to eq(as_map)
    expect(from_map.pick).to eq(from_array.pick)
  end

  it "stores the caller's fingerprint" do
    record = described_class.call(league:, attrs: { "answers" => valid_answers, "weights" => valid_weights },
                                  fingerprint: "fp-abc123").value!

    expect(record.fingerprint).to eq("fp-abc123")
  end

  it "links the returned club(s) through the join table" do
    record = create("answers" => valid_answers, "weights" => valid_weights).value!

    names = record.teams.map(&:name)
    expect(names).to include(record.pick)     # the winner is always linked
    expect(record.teams).to all(be_a(Team))
    expect(names).to eq(names.uniq)           # no duplicate links
  end

  it "mints a distinct slug per completed quiz" do
    a = create("answers" => valid_answers, "weights" => valid_weights).value!
    b = create("answers" => valid_answers, "weights" => valid_weights).value!

    expect(a.slug).not_to eq(b.slug)
    expect(QuizResult.count).to eq(2)
  end

  it "fails when there is no league" do
    result = described_class.call(league: nil, attrs: { "answers" => valid_answers, "weights" => valid_weights })

    expect(result.failure?).to be(true)
    expect(result.failure.first).to eq(:not_found)
  end

  it "rejects the wrong number of answers" do
    result = create("answers" => [0, 1, 2], "weights" => valid_weights)

    expect(result.failure?).to be(true)
    expect(result.failure.first).to eq(:validation)
    expect(result.failure.last).to have_key(:answers)
    expect(QuizResult.count).to eq(0)
  end

  it "rejects an unanswered question" do
    answers = valid_answers.dup
    answers[4] = nil
    result = create("answers" => answers, "weights" => valid_weights)

    expect(result.failure?).to be(true)
    expect(result.failure.first).to eq(:validation)
  end

  it "rejects an out-of-range option index" do
    answers = valid_answers.dup
    answers[0] = 9
    result = create("answers" => answers, "weights" => valid_weights)

    expect(result.failure?).to be(true)
    expect(result.failure.last).to have_key(:answers)
  end

  it "rejects the wrong number of weights" do
    result = create("answers" => valid_answers, "weights" => [5, 5, 5])

    expect(result.failure?).to be(true)
    expect(result.failure.last).to have_key(:weights)
  end

  it "rejects out-of-range weights" do
    result = create("answers" => valid_answers, "weights" => [0, 5, 5, 11])

    expect(result.failure?).to be(true)
    expect(result.failure.last).to have_key(:weights)
  end

  it "rejects a non-array payload" do
    result = create("answers" => "nope", "weights" => valid_weights)

    expect(result.failure?).to be(true)
    expect(result.failure.first).to eq(:validation)
  end
end
