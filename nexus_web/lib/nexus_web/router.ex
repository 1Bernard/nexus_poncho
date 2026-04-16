defmodule NexusWeb.Router do
  use NexusWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {NexusWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", NexusWeb do
    pipe_through :browser

    get "/", PageController, :home
    get "/health", PageController, :health
    live "/onboarding/enroll", Identity.OnboardingLive, :enroll
    live "/onboarding/success", Identity.OnboardingSuccessLive, :show
    live "/register", Identity.UserRegistrationLive, :new
    live "/vaults", Treasury.VaultDashboardLive, :index
    live "/vaults/new", Treasury.VaultRegistrationLive, :new
  end

  # Other scopes may use custom stacks.
  # scope "/api", NexusWeb do
  #   pipe_through :api
  # end

  # Enable LiveDashboard in development
  if Application.compile_env(:nexus_web, :dev_routes) do
    # If you want to use the LiveDashboard in production, you should put
    # it behind authentication and allow only admins to access it.
    # If your application does not have an admins-only section yet,
    # you can use Plug.BasicAuth to set up some basic authentication
    # as long as you are also using SSL (which you should anyway).
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: NexusWeb.Telemetry
    end
  end
end
