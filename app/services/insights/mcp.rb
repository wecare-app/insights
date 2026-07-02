module Insights
  module Mcp
    module_function

    PROTOCOL_VERSION = '2024-11-05'
    SERVER_INFO = { name: 'wecare-insights', version: '0.1.0' }.freeze

    TOOLS = [
      {
        name: 'list_clients',
        description: 'Lista as empresas-clientes ativas (nome, wecare_id, ambiente). Sem dados pessoais.',
        inputSchema: { type: 'object', properties: {}, additionalProperties: false }
      },
      {
        name: 'get_overview',
        description: 'Visão geral agregada de todos os clientes ativos no período. Datas YYYY-MM-DD (padrão = mês corrente).',
        inputSchema: {
          type: 'object',
          properties: {
            start_date: { type: 'string', description: 'YYYY-MM-DD' },
            end_date: { type: 'string', description: 'YYYY-MM-DD' }
          },
          additionalProperties: false
        }
      },
      {
        name: 'get_benchmark_by_porte',
        description: 'Benchmark entre clientes por faixa de porte (nº de colaboradores): mediana/p25/p75 dos big numbers. Datas YYYY-MM-DD.',
        inputSchema: {
          type: 'object',
          properties: {
            start_date: { type: 'string', description: 'YYYY-MM-DD' },
            end_date: { type: 'string', description: 'YYYY-MM-DD' }
          },
          additionalProperties: false
        }
      },
      {
        name: 'get_analytics_by_client_name',
        description: 'Analytics unificados (métricas + listas anonimizadas) de um cliente pelo nome. Datas YYYY-MM-DD.',
        inputSchema: {
          type: 'object',
          properties: {
            client_name: { type: 'string' },
            start_date: { type: 'string' },
            end_date: { type: 'string' },
            sections: { type: 'string', description: 'ex.: recognitions,redemptions' },
            fields: { type: 'string', description: 'ex.: users.list' }
          },
          required: ['client_name'],
          additionalProperties: false
        }
      }
    ].freeze

    # Processa uma mensagem JSON-RPC. Retorna o hash de resposta, ou nil para
    # notificações (que não têm resposta).
    def handle(message)
      id = message['id']

      case message['method']
      when 'initialize'
        result(id, protocolVersion: PROTOCOL_VERSION, capabilities: { tools: {} }, serverInfo: SERVER_INFO)
      when 'notifications/initialized', 'notifications/cancelled'
        nil
      when 'tools/list'
        result(id, tools: TOOLS)
      when 'tools/call'
        params = message['params'] || {}
        begin
          result(id, call_tool(params['name'], params['arguments'] || {}))
        rescue StandardError => e
          result(id, isError: true, content: [{ type: 'text', text: e.message }])
        end
      else
        return nil if id.nil?

        { jsonrpc: '2.0', id: id, error: { code: -32_601, message: "method not found: #{message['method']}" } }
      end
    end

    def result(id, payload)
      return nil if id.nil?

      { jsonrpc: '2.0', id: id, result: payload }
    end

    def call_tool(name, args)
      case name
      when 'list_clients'
        clients = Insights::Analytics.active_companies.map do |c|
          { name: c.name, wecare_id: c.wecare_id, environment: c.environment.name }
        end
        text_result(clients)
      when 'get_overview'
        text_result(Insights::Analytics.overview(params_from(args)))
      when 'get_benchmark_by_porte'
        text_result(Insights::Benchmark.by_porte(params_from(args)))
      when 'get_analytics_by_client_name'
        company = Insights::Analytics.find_company(args['client_name'])
        return text_result({ error: 'client not found' }) unless company

        text_result(Insights::Analytics.company_analytics(company, params_from(args)).merge('client' => company.name))
      else
        raise "unknown tool: #{name}"
      end
    end

    def text_result(data)
      { content: [{ type: 'text', text: JSON.pretty_generate(data) }] }
    end

    def params_from(args)
      args.slice('start_date', 'end_date', 'sections', 'fields', 'limit').symbolize_keys.compact
    end
  end
end
