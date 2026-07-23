# frozen_string_literal: true

require "spec_helper"

RSpec.describe Quiz::Create do
  let(:valid_answers) { Array.new(13, 0) }
  let(:valid_weights) { [5, 5, 5, 5] }

  it "persists a completed quiz and resolves its club" do
    result = described_class.call("answers" => valid_answers, "weights" => valid_weights)

    expect(result.success?).to be(true)
    record = result.value!
    expect(record.pick).to eq("Everton")
    expect(record.slug).to be_a(String)
    expect(record.slug).not_to be_empty
    expect(record.answers).to eq(valid_answers)
    expect(record.weights).to eq(valid_weights)
    expect(QuizResult.count).to eq(1)
  end

  it "mints a distinct slug per completed quiz" do
    a = described_class.call("answers" => valid_answers, "weights" => valid_weights).value!
    b = described_class.call("answers" => valid_answers, "weights" => valid_weights).value!

    expect(a.slug).not_to eq(b.slug)
    expect(QuizResult.count).to eq(2)
  end

  it "rejects the wrong number of answers" do
    result = described_class.call("answers" => [0, 1, 2], "weights" => valid_weights)

    expect(result.failure?).to be(true)
    expect(result.failure.first).to eq(:validation)
    expect(result.failure.last).to have_key(:answers)
    expect(QuizResult.count).to eq(0)
  end

  it "rejects an unanswered question" do
    answers = valid_answers.dup
    answers[4] = nil
    result = described_class.call("answers" => answers, "weights" => valid_weights)

    expect(result.failure?).to be(true)
    expect(result.failure.first).to eq(:validation)
  end

  it "rejects an out-of-range option index" do
    answers = valid_answers.dup
    answers[0] = 9
    result = described_class.call("answers" => answers, "weights" => valid_weights)

    expect(result.failure?).to be(true)
    expect(result.failure.last).to have_key(:answers)
  end

  it "rejects the wrong number of weights" do
    result = described_class.call("answers" => valid_answers, "weights" => [5, 5, 5])

    expect(result.failure?).to be(true)
    expect(result.failure.last).to have_key(:weights)
  end

  it "rejects out-of-range weights" do
    result = described_class.call("answers" => valid_answers, "weights" => [0, 5, 5, 11])

    expect(result.failure?).to be(true)
    expect(result.failure.last).to have_key(:weights)
  end

  it "rejects a non-array payload" do
    result = described_class.call("answers" => "nope", "weights" => valid_weights)

    expect(result.failure?).to be(true)
    expect(result.failure.first).to eq(:validation)
  end
end
