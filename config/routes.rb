PromptTracker::Engine.routes.draw do
  root to: "prompts#index"

  resources :prompts, only: [:index, :show] do
    member do
      get :analytics
    end

    resources :prompt_versions, only: [:show], path: "versions" do
      member do
        get :compare
      end
    end

    # A/B tests nested under prompts for creation
    resources :ab_tests, only: [:new, :create], path: "ab-tests"
  end

  resources :llm_responses, only: [:index, :show], path: "responses"
  resources :evaluations, only: [:index, :show, :create]

  # A/B tests at top level for management
  resources :ab_tests, only: [:index, :show, :edit, :update, :destroy], path: "ab-tests" do
    member do
      post :start
      post :pause
      post :resume
      post :complete
      post :cancel
      get :analyze
    end
  end

  # Analytics & Reports
  namespace :analytics do
    get "/", to: "dashboard#index", as: :root
    get "costs", to: "dashboard#costs"
    get "performance", to: "dashboard#performance"
    get "quality", to: "dashboard#quality"
  end
end
