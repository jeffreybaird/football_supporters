# frozen_string_literal: true

require "spec_helper"
require "faraday"

RSpec.describe Clients::Resend do
  # Faraday's test adapter: real client code, no network.
  def stubbed(api_key: "re_test", &)
    stubs = Faraday::Adapter::Test::Stubs.new(&)
    connection = Faraday.new { |f| f.adapter(:test, stubs) }
    [described_class.new(api_key:, connection:), stubs]
  end

  def email(**overrides)
    described_class::Email.new(from: "quiz@example.com", to: "owner@example.com", subject: "Hi", text: "Body",
                               **overrides)
  end

  def send_one(client) = client.send_email(email)

  describe "#configured?" do
    it "is false without an API key" do
      expect(described_class.new(api_key: nil).configured?).to be(false)
      expect(described_class.new(api_key: "").configured?).to be(false)
    end

    it "is true with an API key" do
      expect(described_class.new(api_key: "re_test").configured?).to be(true)
    end
  end

  it "posts the message and returns the parsed response" do
    # Faraday reuses the env object for the response, so snapshot what we assert
    # on inside the stub rather than holding on to the env itself.
    sent = {}
    client, = stubbed do |stub|
      stub.post("/emails") do |env|
        sent = { body: JSON.parse(env.body), key: env.request_headers["Idempotency-Key"] }
        [200, { "Content-Type" => "application/json" }, '{"id":"re_123"}']
      end
    end

    result = client.send_email(email(reply_to: "them@example.com"), idempotency_key: "feedback-1")

    expect(result.value!).to eq({ "id" => "re_123" })
    expect(sent[:body]).to eq({ "from" => "quiz@example.com", "to" => ["owner@example.com"], "subject" => "Hi",
                                "text" => "Body", "reply_to" => "them@example.com" })
    expect(sent[:key]).to eq("feedback-1")
  end

  it "omits reply_to when none is given" do
    sent = nil
    client, = stubbed do |stub|
      stub.post("/emails") do |env|
        sent = JSON.parse(env.body)
        [200, {}, "{}"]
      end
    end

    send_one(client)

    expect(sent).not_to have_key("reply_to")
  end

  it "fails without calling out when unconfigured" do
    expect(described_class.new(api_key: nil).send_email(email).failure).to eq([:not_configured])
  end

  it "reports an HTTP error" do
    client, = stubbed do |stub|
      stub.post("/emails") { [422, {}, '{"message":"domain not verified"}'] }
    end

    reason, detail = send_one(client).failure
    expect(reason).to eq(:http_error)
    expect(detail).to include("422", "domain not verified")
  end

  it "reports a transport error" do
    client, = stubbed do |stub|
      stub.post("/emails") { raise Faraday::ConnectionFailed, "timed out" }
    end

    expect(send_one(client).failure.first).to eq(:transport_error)
  end
end
