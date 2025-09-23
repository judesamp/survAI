Rails.application.routes.draw do
  root "surveys#index"

  # AI Survey Generation
  get "generate", to: "survey_generator#new", as: :generate_survey
  post "generate", to: "survey_generator#create"

  resources :surveys do
    resources :questions do
      member do
        patch :move_up
        patch :move_down
        post :summarize
      end
    end
    resources :assignments
    member do
      get :builder
      patch :publish
      get :preview
      post :ai_review
      get :dashboard
      post :ai_analysis
      post :generate_data
      delete :reset_assignments
      get :insights
      get :sentiment_analysis
    end
  end

  # Public survey response routes
  get "s/:slug", to: "responses#new", as: :take_survey
  post "s/:slug", to: "responses#create"
  get "s/:slug/complete", to: "responses#complete", as: :survey_complete

  resource :session
  resources :passwords, param: :token
  resources :survey_insights, only: [:index, :show]

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  get "up" => "rails/health#show", as: :rails_health_check
end
