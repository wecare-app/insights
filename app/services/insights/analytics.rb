module Insights
  module Analytics
    module_function

    MAX_CACHE_TTL = 1800
    CACHE_TTL = [ENV.fetch('INSIGHTS_CACHE_TTL', 900).to_i, MAX_CACHE_TTL].min
    # Bump para invalidar todo o cache quando a API do monólito ganha campos novos.
    CACHE_VERSION = 'v2'

    # No overview a dashboard usa só as métricas de cada seção — nunca as listas.
    # Pedir apenas as métricas corta drasticamente o payload por empresa.
    OVERVIEW_FIELDS = %w[
      recognitions.metrics accesses.metrics redemptions.metrics balances company_profile
      gratitudes.metrics feedbacks.metrics one_on_ones.metrics skill_evaluations.metrics
      outcome_evaluations.metrics achievements.metrics social.metrics
    ].join(',').freeze

    OVERVIEW_CONCURRENCY = ENV.fetch('INSIGHTS_OVERVIEW_CONCURRENCY', 8).to_i

    def active_companies
      ClientCompany.active.includes(:environment).select { |c| c.environment.active? }
    end

    def find_company(name_or_id)
      active_companies.find do |c|
        c.name.to_s.casecmp?(name_or_id.to_s) || c.wecare_id.to_s.casecmp?(name_or_id.to_s)
      end
    end

    def company_analytics(client_company, params = {})
      Rails.cache.fetch(cache_key(client_company, params), expires_in: CACHE_TTL) do
        InternalApiClient.new(client_company.environment).data(client_company.wecare_id, params)
      end
    end

    def filter_companies(companies, filter)
      return companies if filter.blank?

      wanted = (filter.is_a?(Array) ? filter : filter.to_s.split(',')).map { |v| v.strip.downcase }.reject(&:blank?)
      return companies if wanted.empty?

      companies.select { |c| wanted.include?(c.wecare_id.to_s.downcase) || wanted.include?(c.name.to_s.downcase) }
    end

    def overview(params = {})
      params = params.dup
      selected = filter_companies(active_companies, params.delete(:companies))
      query = params.merge(fields: OVERVIEW_FIELDS)

      results = fetch_companies(selected, query)

      {
        'clients_considered' => results.map { |r| r['client'] },
        'clients_with_errors' => results.select { |r| r['error'] }.map { |r| r['client'] },
        'totals' => aggregate_totals(results),
        'per_client' => results
      }
    end

    # Busca em paralelo (fan-out de HTTP) para caber no limite de 30s do Heroku
    # com muitas empresas. Um pool de threads consome uma fila de trabalho.
    def fetch_companies(companies, query)
      queue = Queue.new
      companies.each { |c| queue << c }
      results = []
      mutex = Mutex.new
      workers = [OVERVIEW_CONCURRENCY, companies.size].min
      return [] if workers.zero?

      threads = Array.new(workers) do
        Thread.new do
          loop do
            company = begin
              queue.pop(true)
            rescue ThreadError
              break
            end
            row = fetch_company_row(company, query)
            mutex.synchronize { results << row }
          end
        end
      end
      threads.each(&:join)
      results
    end

    def fetch_company_row(company, query)
      data = company_analytics(company, query)
      { 'client' => company.name, 'wecare_id' => company.wecare_id, 'data' => data, 'error' => nil }
    rescue InternalApiClient::Error => e
      { 'client' => company.name, 'wecare_id' => company.wecare_id, 'data' => nil, 'error' => e.message }
    end

    def invalidate(client_company)
      Rails.cache.delete_matched("insights:company:#{client_company.id}:*")
    rescue NotImplementedError
      nil
    end

    def cache_key(client_company, params)
      digest = params.sort.to_h.map { |k, v| "#{k}=#{v}" }.join('&')
      "insights:#{CACHE_VERSION}:company:#{client_company.id}:#{digest}"
    end

    def aggregate_totals(results)
      totals = Hash.new(0)

      results.each do |r|
        data = r['data']
        next unless data

        rec = data.dig('recognitions', 'metrics') || {}
        acc = data.dig('accesses', 'metrics') || {}
        red = data.dig('redemptions', 'metrics') || {}
        bal = data['balances'] || {}

        totals['recognitions_count'] += rec['recognitions_count'].to_i
        totals['distributed_points'] += rec['distributed_points'].to_i
        totals['active_users'] += acc['active_users'].to_i
        totals['successful_logins'] += acc['successful_logins'].to_i
        totals['total_redemptions'] += red['total_redemptions'].to_i
        totals['redeemed_points'] += red['redeemed_points'].to_i
        totals['total_brl'] += red['total_brl'].to_f
        totals['balance_brl'] += bal['total_brl'].to_f
      end

      totals
    end
  end
end
