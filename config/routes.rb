PromptTracker::Engine.routes.draw do
  root to: "home#index"

  # Standalone playground (not tied to a specific prompt)
  resource :playground, only: [ :show ], controller: "playground" do
    post :preview, on: :member
    post :save, on: :member
  end

  resources :prompts, only: [ :index, :show ] do
    member do
      get :analytics
    end

    # Playground for editing existing prompts
    resource :playground, only: [ :show ], controller: "playground" do
      post :preview, on: :member
      post :save, on: :member
      post :generate, on: :member
    end

    resources :prompt_versions, only: [ :show ], path: "versions" do
      member do
        get :compare
        post :activate
      end

      # Playground for specific version
      resource :playground, only: [ :show ], controller: "playground" do
        post :preview, on: :member
        post :save, on: :member
        post :generate, on: :member
      end

      # Tests nested under prompt versions
      resources :prompt_tests, only: [ :index, :new, :create, :show, :edit, :update, :destroy ], path: "tests" do
        collection do
          post :run_all
        end
        member do
          get :compare
          post :activate
        end

        # Playground for specific version
        resource :playground, only: [ :show ], controller: "playground" do
          post :preview, on: :member
          post :save, on: :member
          post :generate, on: :member
        end

        # Tests nested under prompt versions
        resources :prompt_tests, only: [ :index, :new, :create, :show, :edit, :update, :destroy ], path: "tests" do
          collection do
            post :run_all
          end
          member do
            post :run
            get :load_more_runs
          end
        end

        # Datasets nested under prompt versions
        resources :datasets, only: [ :index, :new, :create, :show, :edit, :update, :destroy ] do
          member do
            post :generate_rows # LLM-powered row generation
          end

          # Dataset rows nested under datasets
          resources :dataset_rows, only: [ :create, :update, :destroy ], path: "rows"
        end
      end
    end

    # A/B tests nested under prompts for creation
    resources :ab_tests, only: [ :new, :create ], path: "ab-tests"

    # Evaluator configs nested under prompts
    resources :evaluator_configs, only: [ :index, :show, :create, :update, :destroy ], path: "evaluators"
  end

  resources :llm_responses, only: [ :index, :show ], path: "responses"

  resources :evaluations, only: [ :index, :show, :create ] do
    collection do
      get :form_template
    end
  end

  # ========================================
  # MONITORING SECTION (Green) - Runtime tracking
  # ========================================
  namespace :monitoring do
    get "/", to: "dashboard#index", as: :root

    # Prompts and versions (for monitoring tracked calls)
    resources :prompts, only: [] do
      resources :prompt_versions, only: [ :show ], path: "versions"
    end

    # Evaluations (tracked/runtime calls from all environments)
    resources :evaluations, only: [ :index, :show ] do
      # Human evaluations nested under evaluations
      resources :human_evaluations, only: [ :create ]
    end

    # LLM Responses (tracked calls from all environments)
    resources :llm_responses, only: [ :index ], path: "responses" do
      # Human evaluations nested under llm_responses
      resources :human_evaluations, only: [ :create ]
    end
  end

  # A/B tests at top level for management
  resources :ab_tests, only: [ :index, :show, :edit, :update, :destroy ], path: "ab-tests" do
    member do
      post :start
      post :pause
      post :resume
      post :complete
      post :cancel
      get :analyze
    end
  end

  # Test suites at top level
  resources :prompt_test_suites, only: [ :index, :show, :new, :create, :edit, :update, :destroy ], path: "test-suites" do
    member do
      post :run
    end
  end

  # Test runs (for viewing results)
  resources :prompt_test_runs, only: [ :index, :show ], path: "test-runs"
  resources :prompt_test_suite_runs, only: [ :index, :show ], path: "suite-runs"

  # Analytics & Reports
  namespace :analytics do
    get "/", to: "dashboard#index", as: :root
    get "costs", to: "dashboard#costs"
    get "performance", to: "dashboard#performance"
    get "quality", to: "dashboard#quality"
  end

  # Tracing routes
  resources :sessions, only: [ :index, :show ]
  resources :traces, only: [ :index, :show ]
  resources :spans, only: [ :show ]
end
