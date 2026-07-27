# frozen_string_literal: true

require "spec_helper"

RSpec.describe Feedback do
  it "is valid with only a message" do
    expect(described_class.new(message: "Great quiz")).to be_valid
  end

  it "requires a message" do
    feedback = described_class.new(message: nil)
    expect(feedback).not_to be_valid
    expect(feedback.errors).to include(:message)
  end

  it "rejects a message over the maximum length" do
    feedback = described_class.new(message: "x" * (described_class::MAX_MESSAGE_LENGTH + 1))
    expect(feedback).not_to be_valid
    expect(feedback.errors).to include(:message)
  end

  it "accepts a well-formed email" do
    expect(described_class.new(message: "Hi", email: "someone@example.com")).to be_valid
  end

  it "rejects a malformed email" do
    feedback = described_class.new(message: "Hi", email: "not-an-email")
    expect(feedback).not_to be_valid
    expect(feedback.errors).to include(:email)
  end

  it "rejects an email over the maximum length" do
    long = "#{"a" * described_class::MAX_EMAIL_LENGTH}@example.com"
    feedback = described_class.new(message: "Hi", email: long)
    expect(feedback).not_to be_valid
    expect(feedback.errors).to include(:email)
  end

  it "defaults delivered to false" do
    expect(described_class.create(message: "Hi").delivered).to be(false)
  end

  describe "soft deletes" do
    it "excludes soft-deleted rows from kept" do
      feedback = described_class.create(message: "Hi")
      feedback.soft_delete!
      expect(feedback).to be_deleted
      expect(described_class.kept.where(id: feedback.id).count).to eq(0)
    end
  end

  describe ".recent" do
    it "orders newest first" do
      older = described_class.create(message: "older", created_at: Time.now - 60)
      newer = described_class.create(message: "newer")
      expect(described_class.recent.all.map(&:id).first(2)).to eq([newer.id, older.id])
    end
  end
end
