# frozen_string_literal: true

require "spec_helper"
require_relative "../../app/mcp"

RSpec.describe MCP::Http do
  subject(:transport) { described_class.new(MCP.server) }

  def rpc(method, params = {}, id: 1)
    { "jsonrpc" => "2.0", "id" => id, "method" => method, "params" => params }
  end

  it "answers a single request with one JSON response" do
    status, type, body = transport.post(JSON.generate(rpc("tools/list")))
    expect([status, type]).to eq([200, "application/json"])
    expect(JSON.parse(body)["result"]["tools"]).to be_an(Array)
  end

  it "acknowledges a notification-only body with 202 and no content" do
    status, _type, body = transport.post(JSON.generate("jsonrpc" => "2.0", "method" => "notifications/initialized"))
    expect(status).to eq(202)
    expect(body).to eq("")
  end

  it "answers a batch with an array of responses, in order" do
    status, _type, body = transport.post(JSON.generate([rpc("ping", {}, id: 1), rpc("tools/list", {}, id: 2)]))
    expect(status).to eq(200)
    expect(JSON.parse(body).map { |message| message["id"] }).to eq([1, 2])
  end

  it "returns a JSON-RPC parse error for malformed JSON" do
    status, _type, body = transport.post("{ not json")
    expect(status).to eq(400)
    expect(JSON.parse(body)["error"]["code"]).to eq(-32_700)
  end
end
