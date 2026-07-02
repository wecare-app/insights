Rails.application.config.middleware.use OmniAuth::Builder do
  provider :google_oauth2,
           ENV['GOOGLE_CLIENT_ID'],
           ENV['GOOGLE_CLIENT_SECRET'],
           {
             scope: 'email,profile',
             prompt: 'select_account',
             hd: ENV['OAUTH_ALLOWED_DOMAIN'].presence
           }
end

# Fase de request só por POST (proteção CSRF do omniauth-rails_csrf_protection).
OmniAuth.config.allowed_request_methods = %i[post]
OmniAuth.config.silence_get_warning = true
