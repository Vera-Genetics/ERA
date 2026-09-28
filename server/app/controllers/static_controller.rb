class StaticController < ApplicationController
  # Serves the built Angular app shell (server/public/index.html) for root and
  # for any client-side route reached via the routes.rb catch-all. Without this
  # explicit action, Rails would render the convention view
  # app/views/static/index.html.erb instead - a leftover pre-Angular login
  # stub, not the SPA.
  def index
    render file: Rails.root.join("public", "index.html"), layout: false
  end

  def status
    render json: {
      status: :ok,
      env: Rails.env,
      displayEnvBanner: DISPLAY_ENVIRONMENT_BANNER,
    }
  end
end
