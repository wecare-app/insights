class ClientCompaniesController < ApplicationController
  before_action :require_login!

  def index
    companies = ClientCompany.includes(:environment).order(:name).map do |company|
      {
        id: company.id,
        wecare_id: company.wecare_id,
        name: company.name,
        active: company.active,
        environment: company.environment.name,
        last_synced_at: company.last_synced_at
      }
    end

    render json: companies
  end

  def toggle
    company = ClientCompany.find(params[:id])
    company.update!(active: !company.active)
    Insights::Analytics.invalidate(company)

    render json: { id: company.id, active: company.active }
  end
end
