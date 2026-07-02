class SessionsController < ApplicationController
  def new
    redirect_to root_path if logged_in?
  end

  def create
    auth = request.env['omniauth.auth']
    email = auth&.dig('info', 'email').to_s
    domain = email.split('@').last.to_s
    allowed = ENV['OAUTH_ALLOWED_DOMAIN'].to_s

    if allowed.blank?
      return redirect_to login_path, alert: 'Login indisponível: OAUTH_ALLOWED_DOMAIN não configurado'
    end
    if email.blank? || domain != allowed
      return redirect_to login_path, alert: "Domínio não autorizado: #{domain}"
    end

    reset_session # evita fixação de sessão

    session[:user_email] = email
    redirect_to root_path
  end

  def destroy
    reset_session
    redirect_to login_path
  end

  def failure
    redirect_to login_path, alert: 'Falha no login'
  end
end
