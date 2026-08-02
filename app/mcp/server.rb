# frozen_string_literal: true

require "json"

# A small, hand-rolled Model Context Protocol server — no gem dependency, matching
# the project's "plain Ruby + an explicit require" baseline. MCP::Server is pure:
# it turns one parsed JSON-RPC message into a response hash (or nil for a
# notification), knowing nothing about IO. MCP::Stdio drives it over stdin/stdout.
#
# The tools are read-only and split by space: attribute-space (leagues, clubs) and
# desire-space (score a supporter vector, build a profile). The axis-codebook
# resource is the semantic key that keeps a client from conflating the two.
module MCP
  PROTOCOL_VERSION = "2024-11-05"
  SERVER_INFO = { "name" => "football-supporters", "version" => "0.1.0" }.freeze

  # A JSON-RPC-level failure (bad method, unknown tool/resource) — maps to an
  # `error` response. Distinct from ToolError, which is a handled tool outcome.
  class ProtocolError < StandardError
    attr_reader :code

    def initialize(code, message)
      @code = code
      super(message)
    end
  end

  # An expected, recoverable tool failure (missing arg, unknown club). Surfaced to
  # the model as `isError` content it can read and recover from — not a crash.
  class ToolError < StandardError; end

  Tool = Struct.new(:name, :description, :input_schema, :handler, keyword_init: true) do
    def definition = { "name" => name, "description" => description, "inputSchema" => input_schema }
    def call(arguments) = handler.call(arguments || {})
  end

  Resource = Struct.new(:uri, :name, :description, :mime_type, :reader, keyword_init: true) do
    def definition = { "uri" => uri, "name" => name, "description" => description, "mimeType" => mime_type }
    def read = reader.call
  end

  class Server
    # JSON-RPC method -> handler. tools/* and resources/* split the read-only
    # surface; initialize/ping are the handshake and keepalive.
    ROUTES = {
      "initialize" => :initialize_result, "ping" => :ping_result,
      "tools/list" => :list_tools, "tools/call" => :call_tool,
      "resources/list" => :list_resources, "resources/read" => :read_resource
    }.freeze

    def initialize(tools:, resources:)
      @tools = tools.to_h { |tool| [tool.name, tool] }
      @resources = resources.to_h { |resource| [resource.uri, resource] }
    end

    # Parsed JSON-RPC message in, response hash out. Notifications (no id) are
    # accepted and produce no response (nil).
    def handle(message)
      id = message["id"]
      return nil if id.nil?

      success(id, dispatch(message["method"], message["params"] || {}))
    rescue ProtocolError => e
      failure(id, e.code, e.message)
    rescue StandardError => e
      failure(id, -32_603, "Internal error: #{e.message}")
    end

    private

    def dispatch(method, params)
      handler = ROUTES[method]
      raise ProtocolError.new(-32_601, "Method not found: #{method}") unless handler

      send(handler, params)
    end

    def initialize_result(params)
      { "protocolVersion" => params["protocolVersion"] || PROTOCOL_VERSION,
        "capabilities" => { "tools" => {}, "resources" => {} },
        "serverInfo" => SERVER_INFO }
    end

    def ping_result(_params) = {}
    def list_tools(_params) = { "tools" => @tools.values.map(&:definition) }
    def list_resources(_params) = { "resources" => @resources.values.map(&:definition) }

    def call_tool(params)
      tool = @tools[params["name"]]
      raise ProtocolError.new(-32_602, "Unknown tool: #{params["name"]}") unless tool

      text(JSON.pretty_generate(tool.call(params["arguments"])))
    rescue ToolError => e
      text(e.message, error: true)
    end

    def read_resource(params)
      resource = @resources[params["uri"]]
      raise ProtocolError.new(-32_602, "Unknown resource: #{params["uri"]}") unless resource

      { "contents" => [{ "uri" => resource.uri, "mimeType" => resource.mime_type, "text" => resource.read }] }
    end

    def text(string, error: false)
      { "content" => [{ "type" => "text", "text" => string }], "isError" => error }
    end

    def success(id, result) = { "jsonrpc" => "2.0", "id" => id, "result" => result }

    def failure(id, code, message)
      { "jsonrpc" => "2.0", "id" => id, "error" => { "code" => code, "message" => message } }
    end
  end
end
