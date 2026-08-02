# frozen_string_literal: true

require "json"

module MCP
  # Streamable HTTP transport: one HTTP POST carrying a JSON-RPC message (or a
  # batch) in, one JSON response out. Stateless and read-only — no sessions, no
  # server-initiated SSE — so a single application/json response per POST is
  # spec-compliant and sufficient for these synchronous tools. Mounted at POST /mcp
  # (see app.rb) and sharing MCP::Server with the stdio transport, so a remote
  # Claude client (custom connector by URL) calls exactly the same tools.
  class Http
    JSON_TYPE = "application/json"

    def initialize(server)
      @server = server
    end

    # Handle one POST body. Returns [status, content_type_or_nil, body_string] so
    # the Sinatra route stays a thin adapter. A body that is only notifications /
    # responses (nothing needing a reply) is acknowledged with 202 and no content.
    def post(raw_body)
      messages = parse(raw_body)
      return parse_error if messages.nil?

      batch = messages.is_a?(Array)
      responses = (batch ? messages : [messages]).filter_map { |message| @server.handle(message) }
      return [202, nil, ""] if responses.empty?

      [200, JSON_TYPE, JSON.generate(batch ? responses : responses.first)]
    end

    private

    def parse(raw_body)
      JSON.parse(raw_body)
    rescue JSON::ParserError
      nil
    end

    def parse_error
      body = { "jsonrpc" => "2.0", "id" => nil, "error" => { "code" => -32_700, "message" => "Parse error" } }
      [400, JSON_TYPE, JSON.generate(body)]
    end
  end
end
