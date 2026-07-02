module Api
  class AnalyticsController < ApplicationController
    before_action :require_login!

    def overview
      render json: Insights::Analytics.overview(query_params)
    end

    def benchmark
      render json: Insights::Benchmark.by_porte(query_params)
    end

    def show
      company = Insights::Analytics.find_company(params[:name])
      return render(json: { error: 'client not found' }, status: :not_found) unless company

      data = Insights::Analytics.company_analytics(company, query_params)
      render json: data.merge('client' => company.name)
    rescue Insights::InternalApiClient::Error => e
      render json: { error: e.message }, status: :bad_gateway
    end

    private

    def query_params
      params.permit(:start_date, :end_date, :sections, :fields, :limit, :after, :companies).to_h.symbolize_keys.compact
    end
  end
end
