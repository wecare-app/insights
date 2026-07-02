class EnvironmentsController < ApplicationController
  before_action :require_login!

  def index
    render json: Environment.order(:name).map { |env| serialize(env) }
  end

  def create
    env = Environment.new(environment_params)
    env.token = params[:token] if params[:token].present?

    if env.save
      render json: serialize(env), status: :created
    else
      render json: { errors: env.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def sync
    Insights::Sync.all
    render json: { ok: true, companies: ClientCompany.count }
  end

  private

  def environment_params
    params.permit(:name, :base_url, :db_type, :active)
  end

  # Nunca inclui o token.
  def serialize(env)
    {
      id: env.id,
      name: env.name,
      base_url: env.base_url,
      db_type: env.db_type,
      active: env.active,
      companies: env.client_companies.count
    }
  end
end
