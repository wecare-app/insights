class ClientCompaniesController < ApplicationController
  before_action :require_login!

  def index
    companies = ClientCompany.includes(:environment).order(:name).map do |company|
      {
        id: company.id,
        wecare_id: company.wecare_id,
        name: company.name,
        status: company.status,
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

  def destroy
    company = ClientCompany.find(params[:id])
    Insights::Analytics.invalidate(company)
    company.destroy!

    head :no_content
  end

  # Remove de uma vez todas as empresas desabilitadas (ex.: bloqueadas no produto).
  def destroy_disabled
    removed = ClientCompany.where(active: false).destroy_all.size

    render json: { removed: removed }
  end
end
