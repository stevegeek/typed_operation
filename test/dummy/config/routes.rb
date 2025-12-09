Rails.application.routes.draw do
  # Simple routes for demo app
  resources :products, only: [:index, :create]

  resources :orders, only: [:index, :create] do
    post :via_pipeline, on: :collection, action: :create_via_pipeline
  end
end
