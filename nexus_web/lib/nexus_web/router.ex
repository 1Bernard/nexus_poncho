defmodule NexusWeb.Router do
  use NexusWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {NexusWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug NexusWeb.UserAuth
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  # ── Public routes ─────────────────────────────────────────────────────────

  scope "/", NexusWeb do
    pipe_through :browser

    get "/", Marketing.PageController, :home
    get "/health", Marketing.PageController, :health

    live_session :marketing, layout: {NexusWeb.Layouts, :marketing} do
      live "/request-access", Marketing.RequestAccessLive, :new
    end

    live_session :public,
      on_mount: [{NexusWeb.UserAuth, :fetch_current_user}] do
      live "/login", Identity.LoginLive, :index
      live "/register", Identity.UserRegistrationLive, :new
      live "/onboarding/enroll", Identity.OnboardingLive, :enroll
      live "/onboarding/success", Identity.OnboardingSuccessLive, :show
    end

    # ── Protected controller routes (biometric session required) ──────────
    # Auth is enforced by each controller's ensure_authenticated plug.
    # The :browser pipeline above sets current_user via UserAuth.

    get "/admin/access-requests/export", Admin.ExportController, :export

    # ── Protected LiveView routes (biometric session required) ─────────────

    live_session :authenticated,
      on_mount: [{NexusWeb.UserAuth, :require_authenticated}] do
      live "/vaults", Treasury.VaultDashboardLive, :index
      live "/vaults/new", Treasury.VaultRegistrationLive, :new
      live "/admin/access-requests", Admin.RequestAccessAdminLive, :index
    end
  end

  # ── Auth controller (session cookie exchange + logout) ────────────────────

  scope "/auth", NexusWeb do
    pipe_through :browser

    get "/finalise", Identity.AuthController, :finalise
    delete "/logout", Identity.AuthController, :logout
  end

  # ── Dev tools ─────────────────────────────────────────────────────────────

  if Application.compile_env(:nexus_web, :dev_routes) do
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser
      live_dashboard "/dashboard", metrics: NexusWeb.Telemetry
    end
  end
end
