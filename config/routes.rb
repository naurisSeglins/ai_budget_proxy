Rails.application.routes.draw do
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Health endpoint for Fly + UptimeRobot. Verifies the app booted AND the DB
  # is reachable; returns 503 if the DB is down so the load balancer can route
  # away from this instance.
  get "up" => "health#show", as: :rails_health_check

  post "proxy", to: "proxy#create"
  post "tokens", to: "tokens#create"
  get  "tokens", to: "tokens#index"
end
