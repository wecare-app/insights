module Insights
  module Benchmark
    module_function

    SECTIONS = 'company_profile,recognitions,accesses,redemptions,balances'.freeze

    METRICS = {
      'recognitions_count' => ->(d) { d.dig('recognitions', 'metrics', 'recognitions_count') },
      'active_users'       => ->(d) { d.dig('accesses', 'metrics', 'active_users') },
      'successful_logins'  => ->(d) { d.dig('accesses', 'metrics', 'successful_logins') },
      'total_redemptions'  => ->(d) { d.dig('redemptions', 'metrics', 'total_redemptions') },
      'redeemed_brl'       => ->(d) { d.dig('redemptions', 'metrics', 'total_brl') },
      'balance_brl'        => ->(d) { d.dig('balances', 'total_brl') }
    }.freeze

    def by_porte(params = {})
      query = params.merge(sections: SECTIONS, limit: 1)
      grouped = Hash.new { |hash, key| hash[key] = [] }

      Analytics.active_companies.each do |company|
        data = Analytics.company_analytics(company, query)
        porte = data.dig('company_profile', 'porte')
        grouped[porte] << data if porte.present?
      rescue InternalApiClient::Error
        next
      end

      { 'buckets' => build_buckets(grouped) }
    end

    def build_buckets(grouped)
      grouped.transform_values do |datasets|
        { 'companies' => datasets.size, 'metrics' => bucket_metrics(datasets) }
      end
    end

    def bucket_metrics(datasets)
      METRICS.transform_values do |extractor|
        values = datasets.map { |data| extractor.call(data).to_f }
        {
          'median' => percentile(values, 50),
          'p25' => percentile(values, 25),
          'p75' => percentile(values, 75)
        }
      end
    end

    def percentile(values, pct)
      return 0.0 if values.empty?

      sorted = values.sort
      rank = (pct / 100.0) * (sorted.size - 1)
      lower = sorted[rank.floor]
      upper = sorted[rank.ceil]
      (lower + (upper - lower) * (rank - rank.floor)).round(2)
    end
  end
end
