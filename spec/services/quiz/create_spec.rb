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
    expect(record.pick).to eq("Everton")
    expect(record.league_id).to eq(league.id)
    expect(record.slug).to be_a(String)
    expect(record.slug).not_to be_empty
    expect(record.answers).to eq(valid_answers)
    expect(record.weights).to eq(valid_weights)
    expect(QuizResult.count).to eq(1)
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
