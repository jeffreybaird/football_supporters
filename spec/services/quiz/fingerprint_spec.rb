# frozen_string_literal: true

require "spec_helper"

RSpec.describe Quiz::Fingerprint do
  def request_for(client_ip: "203.0.113.7", user_agent: "Mozilla/5.0", accept_lang: "en-US")
    env = Rack::MockRequest.env_for("/quizzes")
    env["REMOTE_ADDR"] = client_ip if client_ip
    env["HTTP_USER_AGENT"] = user_agent if user_agent
    env["HTTP_ACCEPT_LANGUAGE"] = accept_lang if accept_lang
    Rack::Request.new(env)
  end

  it "produces a stable hex digest for the same ip + browser signals" do
    a = described_class.call(request_for)
    b = described_class.call(request_for)

    expect(a).to match(/\A[0-9a-f]{64}\z/)
    expect(a).to eq(b)
  end

  it "distinguishes a different ip" do
    expect(described_class.call(request_for(client_ip: "198.51.100.1")))
      .not_to eq(described_class.call(request_for(client_ip: "203.0.113.7")))
  end

  it "distinguishes a different browser (user agent)" do
    expect(described_class.call(request_for(user_agent: "curl/8")))
      .not_to eq(described_class.call(request_for(user_agent: "Mozilla/5.0")))
  end

  it "does not store the raw ip or headers" do
    fp = described_class.call(request_for(client_ip: "203.0.113.7", user_agent: "SecretUA"))

    expect(fp).not_to include("203.0.113.7")
    expect(fp).not_to include("SecretUA")
  end

  it "returns nil when there is nothing to fingerprint" do
    env = Rack::MockRequest.env_for("/quizzes")
    env.delete("HTTP_USER_AGENT")
    env.delete("HTTP_ACCEPT_LANGUAGE")
    env["REMOTE_ADDR"] = ""
    expect(described_class.call(Rack::Request.new(env))).to be_nil
  end
end
