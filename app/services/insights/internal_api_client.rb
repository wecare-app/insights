module Insights
  class InternalApiClient
    class Error < StandardError; end

    GENERIC_ERROR = 'ambiente indisponível'

    def initialize(environment)
      @environment = environment
    end

    def companies
      get('/insights/v1/companies').fetch('companies', [])
    end

    def data(wecare_id, params = {})
      get('/insights/v1/data', { company: wecare_id }.merge(params.compact))
    end

    private

    def connection
      @connection ||= Faraday.new(url: @environment.base_url) do |f|
        f.request :url_encoded
        f.options.timeout = ENV.fetch('INSIGHTS_TIMEOUT', 15).to_i
        # Não adicionar follow_redirects: seguir redirects reabriria SSRF.
        f.adapter Faraday.default_adapter
      end
    end

    def get(path, params = {})
      response = connection.get(path, params) do |req|
        req.headers['Authorization'] = "Bearer #{@environment.token}"
        req.headers['Accept'] = 'application/json'
      end

      unless response.success?
        log_failure(path, "status #{response.status}")
        raise Error, GENERIC_ERROR
      end

      JSON.parse(response.body)
    rescue Faraday::Error => e
      log_failure(path, "#{e.class}: #{e.message}")
      raise Error, GENERIC_ERROR
    rescue JSON::ParserError
      log_failure(path, 'resposta não-JSON')
      raise Error, GENERIC_ERROR
    end

    def log_failure(path, detail)
      Rails.logger.warn("[insights api] #{@environment.name} #{path}: #{detail}")
    end
  end
end
