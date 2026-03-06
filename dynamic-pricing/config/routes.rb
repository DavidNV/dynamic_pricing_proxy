Rails.application.routes.draw do
  namespace :api do
    namespace :v1 do
      get  '/pricing', to: 'pricing#index'
      post '/pricing', to: 'pricing#create'
      get  '/health',  to: 'health#show'
    end
  end
end