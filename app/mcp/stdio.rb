# frozen_string_literal: true

require "json"

module MCP
  # The stdio transport: newline-delimited JSON-RPC on stdin/stdout, one message
  # per line (the MCP stdio framing). Thin IO wrapper around MCP::Server — all the
  # protocol logic lives there; this only reads, parses, and writes.
  class Stdio
    def initialize(server, input: $stdin, output: $stdout)
      @server = server
      @input = input
      @output = output
    end

    def run
      while (line = @input.gets)
        process(line.strip)
      end
    end

    private

    def process(line)
      return if line.empty?

      message = parse(line)
      return write(parse_error) if message.nil?

      response = @server.handle(message)
      write(response) if response
    end

    def parse(line)
      JSON.parse(line)
    rescue JSON::ParserError
      nil
    end

    def write(object)
      @output.puts(JSON.generate(object))
      @output.flush
    end

    def parse_error
      { "jsonrpc" => "2.0", "id" => nil, "error" => { "code" => -32_700, "message" => "Parse error" } }
    end
  end
end
