Admin::Engine.routes.draw do

  match "/" => "dashboard#show", :as => "admin_dashboard"
  match "user_guide" => "base#user_guide"

  if Typus.authentication == :session
    resource :session, :only => [:new, :create, :destroy], :controller => :session
    resources :account, :only => [:new, :create, :show, :forgot_password] do
      collection { get :forgot_password }
    end
  end

  Typus.resources.map { |i| i.underscore }.each do |resource|
    match "#{resource}(/:action(/:id(.:format)))", :controller => resource
  end

  Typus.models.map { |i| i.to_resource }.each do |resource|
    match "#{resource}(/:action(/:id(.:format)))", :controller => resource
  end

end
