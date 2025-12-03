PromptTracker::Engine.routes.draw do
  root to: "home#index"

  # ========================================
  # TESTING SECTION (Blue) - Pre-deployment validation
  # ========================================
  namespace :testing do
    get "/", to: "dashboard#index", as: :root

    # Standalone playground (not tied to a specific prompt)
    resource :playground, only: [:show], controller: 'playground' do
      post :preview, on: :member
      post :save, on: :member
    end

    resources :prompts, only: [:index, :show] do
      # Playground for editing existing prompts
      resource :playground, only: [:show], controller: 'playground' do
        post :preview, on: :member
        post :save, on: :member
      end

      resources :prompt_versions, only: [:show], path: "versions" do
        member do
          get :compare
          post :activate
        end

        # Playground for specific version
        resource :playground, only: [:show], controller: 'playground' do
          post :preview, on: :member
          post :save, on: :member
        end

        # Tests nested under prompt versions
        resources :prompt_tests, only: [:index, :new, :create, :show, :edit, :update, :destroy], path: "tests" do
          collection do
            post :run_all
          end
          member do
            post :run
          end
        end
      end

    end

    # Test runs (for viewing results)
    resources :runs, controller: "prompt_test_runs", only: [:index, :show]
  end

  # ========================================
  # MONITORING SECTION (Green) - Runtime tracking
  # ========================================
  namespace :monitoring do
    get "/", to: "dashboard#index", as: :root

    # Evaluations (tracked/runtime calls from all environments)
    resources :evaluations, only: [:index, :show] do
      # Human evaluations nested under evaluations
      resources :human_evaluations, only: [:create]
    end

    # LLM Responses (tracked calls from all environments)
    resources :llm_responses, only: [:index], path: "responses"
  end

  # Prompts (for monitoring - evaluator configs)
  resources :prompts, only: [] do
    # Evaluator configs nested under prompts (for monitoring)
    resources :evaluator_configs, only: [ :index, :show, :create, :update, :destroy ], path: "evaluators"
  end

  # LLM Responses (used by both monitoring and legacy routes)
  resources :llm_responses, only: [:index, :show], path: "responses" do
    collection do
      get :search
    end
  end

  # Evaluations (used by both monitoring and test sections)
  resources :evaluations, only: [:index, :show, :create] do
    collection do
      get :form_template
    end
    # Human evaluations nested under evaluations
    resources :human_evaluations, only: [:create]
  end

  # Evaluator config forms (not nested, for AJAX loading)
  resources :evaluator_configs, only: [] do
    collection do
      get :config_form
    end
  end

  # Test runs (legacy, redirects to /testing/runs)
  resources :prompt_test_runs, only: [:index, :show], path: "test-runs"
end
