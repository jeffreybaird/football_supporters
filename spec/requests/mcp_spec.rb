# frozen_string_literal: true

require "spec_helper"

RSpec.describe "MCP HTTP endpoint", type: :request do
  def post_rpc(method, params = {}, id: 1)
    body = JSON.generate("jsonrpc" => "2.0", "id" => id, "method" => method, "params" => params)
    post "/mcp", body, { "CONTENT_TYPE" => "application/json" }
  end

  it "handshakes over POST /mcp" do
    post_rpc("initialize", { "protocolVersion" => "2024-11-05" })
    expect(last_response.status).to eq(200)
    expect(last_response.content_type).to include("application/json")
    expect(JSON.parse(last_response.body)["result"]["serverInfo"]["name"]).to eq("football-supporters")
  end

  it "calls a tool and returns its content" do
    args = { "vector" => [7, 8, 6, 5], "league" => League.default.slug }
    post_rpc("tools/call", { "name" => "score_supporter", "arguments" => args })
    payload = JSON.parse(JSON.parse(last_response.body)["result"]["content"].first["text"])
    expect(payload["pick"]).to include("name", "match_pct")
  end

  it "acknowledges a notification with 202" do
    post "/mcp", JSON.generate("jsonrpc" => "2.0", "method" => "notifications/initialized"),
         { "CONTENT_TYPE" => "application/json" }
    expect(last_response.status).to eq(202)
  end

  it "rejects GET with 405" do
    get "/mcp"
    expect(last_response.status).to eq(405)
    expect(last_response.headers["Allow"]).to eq("POST")
  end
end
