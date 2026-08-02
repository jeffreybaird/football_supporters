# frozen_string_literal: true

require "spec_helper"
require_relative "../../app/mcp"

RSpec.describe MCP::Server do
  subject(:server) { MCP.server }

  let(:league) { League.default.slug }

  def req(method, params = {}, id: 1)
    server.handle({ "jsonrpc" => "2.0", "id" => id, "method" => method, "params" => params })
  end

  it "handshakes on initialize" do
    result = req("initialize", { "protocolVersion" => "2024-11-05" })["result"]
    expect(result["serverInfo"]["name"]).to eq("football-supporters")
    expect(result["capabilities"]).to include("tools", "resources")
  end

  it "accepts a notification (no id) with no response" do
    expect(server.handle({ "method" => "notifications/initialized" })).to be_nil
  end

  it "lists the split tool surface" do
    names = req("tools/list")["result"]["tools"].map { |tool| tool["name"] }
    expect(names).to include("list_leagues", "list_teams", "score_supporter", "build_profile", "explain_match")
  end

  it "returns a JSON-RPC error for an unknown method" do
    expect(req("bogus/method")["error"]["code"]).to eq(-32_601)
  end

  it "scores a supporter vector into ranked clubs" do
    args = { "vector" => [7, 8, 6, 5], "league" => league }
    result = req("tools/call", { "name" => "score_supporter", "arguments" => args })["result"]
    payload = JSON.parse(result["content"].first["text"])
    expect(payload["pick"]).to include("name", "match_pct")
    expect(payload["archetype"]).to include("label")
  end

  it "surfaces a tool failure as isError content, not a protocol error" do
    args = { "vector" => [7, 8, 6, 5], "league" => "nope" }
    call = req("tools/call", { "name" => "score_supporter", "arguments" => args })
    expect(call["result"]["isError"]).to be(true)
    expect(call["error"]).to be_nil
  end

  it "reads the axis-codebook resource" do
    read = req("resources/read", { "uri" => "footballsupporters://axis-codebook" })
    book = JSON.parse(read["result"]["contents"].first["text"])
    expect(book["axes"].keys).to eq(Quiz::Data::AXES)
  end

  it "exposes the conversation guide as a resource" do
    uris = req("resources/list")["result"]["resources"].map { |resource| resource["uri"] }
    expect(uris).to include("footballsupporters://conversation-guide")
    read = req("resources/read", { "uri" => "footballsupporters://conversation-guide" })
    expect(read["result"]["contents"].first["text"]).to match(/never ask/i)
  end
end
