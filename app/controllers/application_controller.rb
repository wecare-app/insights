class ApplicationController < ActionController::Base
  helper_method :current_user_email, :logged_in?

  private

  def current_user_email
    session[:user_email].presence || dev_bypass_email
  end

  def logged_in?
    current_user_email.present?
  end

  def require_login!
    return if logged_in?

    respond_to do |format|
      format.html { redirect_to login_path }
      format.json { render json: { error: 'unauthorized', login: login_path }, status: :unauthorized }
    end
  end

  # Bypass de login só em development.
  def dev_bypass_email
    return nil unless Rails.env.development?
    return nil if oauth_configured?

    "dev@#{ENV['OAUTH_ALLOWED_DOMAIN'].presence || 'local'}"
  end

  def oauth_configured?
    ENV['GOOGLE_CLIENT_ID'].present? && ENV['GOOGLE_CLIENT_SECRET'].present?
  end
end
