# frozen_string_literal: true

require_relative "mcp/server"
require_relative "mcp/tools"
require_relative "mcp/resources"
require_relative "mcp/stdio"

# The MCP server assembly. Requires the protocol core plus the tool and resource
# tables; `MCP.server` wires them into a ready Server. Loaded by bin/mcp (after the
# app environment) and by the specs.
module MCP
  module_function

  def server = Server.new(tools: Tools.all, resources: Resources.all)
end
