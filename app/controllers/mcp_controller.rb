# MCP remoto (Streamable HTTP) para conectar o Claude.ai como "custom connector".
# Autenticado por token (?key= na URL ou header Authorization: Bearer). Não usa o
# login do dashboard porque quem chama é o servidor do Claude, não um navegador logado.
class McpController < ActionController::API
  def handle
    return render_unauthorized unless authorized?

    payload = parse_body
    return render(json: parse_error, status: :bad_request) if payload.nil?

    if payload.is_a?(Array)
      responses = payload.map { |message| Insights::Mcp.handle(message) }.compact
      return head(:accepted) if responses.empty?

      render json: responses
    else
      set_session_header(payload)
      response = Insights::Mcp.handle(payload)
      response.nil? ? head(:accepted) : render(json: response)
    end
  end

  # O Claude.ai pode abrir um GET para SSE; não emitimos mensagens server->client.
  def stream
    head :method_not_allowed
  end

  private

  def parse_body
    raw = request.body.read
    return nil if raw.blank?

    JSON.parse(raw)
  rescue JSON::ParserError
    nil
  end

  def parse_error
    { jsonrpc: '2.0', id: nil, error: { code: -32_700, message: 'parse error' } }
  end

  def set_session_header(payload)
    return unless payload.is_a?(Hash) && payload['method'] == 'initialize'

    response.set_header('Mcp-Session-Id', SecureRandom.hex(16))
  end

  def authorized?
    provided = params[:key].presence || bearer_token
    expected = ENV['MCP_TOKEN'].to_s
    return false if expected.blank? || provided.blank?

    ActiveSupport::SecurityUtils.fixed_length_secure_compare(
      ::Digest::SHA256.hexdigest(provided),
      ::Digest::SHA256.hexdigest(expected)
    )
  end

  def bearer_token
    request.get_header('HTTP_AUTHORIZATION').to_s.split('Bearer ').last.presence
  end

  def render_unauthorized
    render json: { error: 'unauthorized' }, status: :unauthorized
  end
end
