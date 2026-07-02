Rails.application.routes.draw do
  root 'dashboard#index'
  get '/empresas', to: 'manage#index'

  get '/health', to: proc { [200, { 'Content-Type' => 'application/json' }, ['{"status":"ok"}']] }

  # Autenticação (OAuth Google)
  get '/login', to: 'sessions#new'
  get '/auth/:provider/callback', to: 'sessions#create'
  get '/auth/failure', to: 'sessions#failure'
  delete '/logout', to: 'sessions#destroy'

  # API JSON consumida pelo dashboard
  namespace :api do
    get 'overview', to: 'analytics#overview'
    get 'benchmark', to: 'analytics#benchmark'
    get 'companies/:name', to: 'analytics#show', constraints: { name: /[^\/]+/ }
  end

  # Registro de ambientes e empresas (ativa/inativa)
  resources :environments, only: %i[index create] do
    post :sync, on: :collection
  end
  resources :client_companies, only: %i[index] do
    post :toggle, on: :member
  end
end
