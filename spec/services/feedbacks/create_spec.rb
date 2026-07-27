# frozen_string_literal: true

require "spec_helper"

RSpec.describe Feedbacks::Create do
  # A verifying double for Feedbacks::Notify — no ENV, no network.
  let(:notifier) { instance_double(Feedbacks::Notify) }
  let(:notify_result) { Dry::Monads::Success({}) }

  before { allow(notifier).to receive(:call).and_return(notify_result) }

  def create(attrs)
    described_class.new(notifier:).call(attrs:)
  end

  it "stores a message-only submission" do
    result = create({ "message" => "  Love this  " })

    expect(result).to be_success
    feedback = result.value!
    expect(feedback.message).to eq("Love this")
    expect(feedback.email).to be_nil
    expect(Feedback[feedback.id]).not_to be_nil
  end

  it "stores an optional email and page" do
    result = create({ "message" => "Nice", "email" => " me@example.com ", "page" => "http://example.org/q/abc" })

    feedback = result.value!
    expect(feedback.email).to eq("me@example.com")
    expect(feedback.page).to eq("http://example.org/q/abc")
  end

  it "treats a blank email as no email" do
    expect(create({ "message" => "Nice", "email" => "   " }).value!.email).to be_nil
  end

  it "notifies with the persisted feedback and marks it delivered" do
    result = create({ "message" => "Nice" })

    expect(notifier).to have_received(:call).with(feedback: result.value!)
    expect(Feedback[result.value!.id].delivered).to be(true)
  end

  context "when the notification fails" do
    let(:notify_result) { Dry::Monads::Failure([:not_configured]) }

    it "still succeeds, leaving the row undelivered" do
      result = create({ "message" => "Nice" })

      expect(result).to be_success
      expect(Feedback[result.value!.id].delivered).to be(false)
    end
  end

  it "rejects an empty message" do
    result = create({ "message" => "   " })

    expect(result.failure.first).to eq(:validation)
    expect(result.failure.last).to include(:message)
    expect(notifier).not_to have_received(:call)
  end

  it "rejects a message over the maximum length" do
    result = create({ "message" => "x" * (Feedback::MAX_MESSAGE_LENGTH + 1) })

    expect(result.failure.first).to eq(:validation)
    expect(Feedback.count).to eq(0)
  end

  it "rejects a malformed email without storing anything" do
    result = create({ "message" => "Nice", "email" => "nope" })

    expect(result.failure.first).to eq(:validation)
    expect(result.failure.last).to include(:email)
    expect(Feedback.count).to eq(0)
  end

  it "silently drops a submission that fills the honeypot" do
    result = create({ "message" => "buy pills", described_class::HONEYPOT_FIELD => "http://spam.example" })

    expect(result.failure).to eq([:spam])
    expect(Feedback.count).to eq(0)
    expect(notifier).not_to have_received(:call)
  end
end
