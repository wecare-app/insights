class AiController < ApplicationController
  before_action :require_login!

  def index
    token = ENV['MCP_TOKEN'].presence
    @mcp_url = "#{request.base_url}/mcp?key=#{token}" if token
  end
end
