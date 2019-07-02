Rails.application.routes.draw do
  root "reports#index"
  resources :policies
  resources :companies
  resources :employees
  resources :reports, only: [:index] do
    post :import, on: :collection
    get :import_status, on: :collection
  end
  # For details on the DSL available within this file, see http://guides.rubyonrails.org/routing.html
end
