# frozen_string_literal: true

require "spec_helper"

RSpec.describe Feedbacks::Notify do
  let(:client) { instance_double(Clients::Resend) }
  let(:feedback) { Feedback.create(message: "The Bundesliga pick felt wrong", email: "me@example.com", page: "/q/abc") }

  before { allow(client).to receive(:send_email).and_return(Dry::Monads::Success({ "id" => "re_1" })) }

  # ENV is read in the constructor, so set it around construction and restore it.
  def with_env(vars)
    previous = vars.keys.to_h { |k| [k, ENV.fetch(k, nil)] }
    vars.each { |k, v| v.nil? ? ENV.delete(k) : ENV[k] = v }
    yield
  ensure
    previous.each { |k, v| v.nil? ? ENV.delete(k) : ENV[k] = v }
  end

  def notify(record = feedback, to: "owner@example.com", from: "quiz@example.com")
    with_env("FEEDBACK_TO_EMAIL" => to, "FEEDBACK_FROM_EMAIL" => from) do
      described_class.new(client:).call(feedback: record)
    end
  end

  it "sends to the configured inbox from the configured sender" do
    expect(notify).to be_success
    expect(client).to have_received(:send_email) do |email, **|
      expect(email.to).to eq("owner@example.com")
      expect(email.from).to eq("quiz@example.com")
    end
  end

  it "puts a preview of the message in the subject" do
    notify
    expect(client).to have_received(:send_email) do |email, **|
      expect(email.subject).to eq("Feedback: The Bundesliga pick felt wrong")
    end
  end

  it "truncates a long subject" do
    notify(Feedback.create(message: "x" * 200))
    expect(client).to have_received(:send_email) do |email, **|
      expect(email.subject).to eq("Feedback: #{"x" * described_class::SUBJECT_PREVIEW_LENGTH}…")
    end
  end

  it "sets reply-to from the submitted email" do
    notify
    expect(client).to have_received(:send_email) { |email, **| expect(email.reply_to).to eq("me@example.com") }
  end

  it "leaves reply-to nil when no email was given" do
    notify(Feedback.create(message: "no address here"))
    expect(client).to have_received(:send_email) { |email, **| expect(email.reply_to).to be_nil }
  end

  it "includes the message, email and page in the body" do
    notify
    expect(client).to have_received(:send_email) do |email, **|
      expect(email.text).to include("The Bundesliga pick felt wrong", "me@example.com", "/q/abc")
    end
  end

  it "sends a per-feedback idempotency key" do
    notify
    expect(client).to have_received(:send_email).with(anything, idempotency_key: "feedback-#{feedback.id}")
  end

  it "is a no-op failure when the destination is unset" do
    expect(notify(to: nil).failure).to eq([:not_configured])
    expect(client).not_to have_received(:send_email)
  end

  it "is a no-op failure when the sender is unset" do
    expect(notify(from: nil).failure).to eq([:not_configured])
    expect(client).not_to have_received(:send_email)
  end
end
