defmodule NexusWeb.UserAuth do
  @moduledoc """
  Authentication boundary for the web layer.

  Provides:
  - `fetch_current_user/2`  — Plug: loads current_user from biometric session cookie
  - `require_authenticated/2` — Plug: halts and redirects if not authenticated
  - `on_mount/4` — LiveView hook: used in live_session :authenticated
  - `log_out/1`  — Helper: clears the session and returns the conn
  """
  import Plug.Conn
  import Phoenix.Controller

  alias Nexus.Identity.Projections.{Session, User}
  alias Nexus.Repo

  require Logger

  # ── Plugs ────────────────────────────────────────────────────────────────

  def init(opts), do: opts

  def call(conn, _opts), do: fetch_current_user(conn)

  @doc "Loads current_user into conn.assigns from the session cookie."
  def fetch_current_user(conn) do
    session_id = get_session(conn, :session_id)
    assign(conn, :current_user, resolve_user(session_id))
  end

  @doc "Redirects unauthenticated requests to /login."
  def require_authenticated(conn, _opts) do
    if conn.assigns[:current_user] do
      conn
    else
      conn
      |> put_flash(:error, "Please authenticate to continue.")
      |> redirect(to: "/login")
      |> halt()
    end
  end

  @doc "Clears the session. Call before redirecting to /login on logout."
  def log_out(conn) do
    clear_session(conn)
  end

  # ── LiveView on_mount callbacks ──────────────────────────────────────────

  @doc """
  LiveView hook — loads current_user without requiring authentication.
  Use in `live_session :public` to make current_user available but optional.
  """
  def on_mount(:fetch_current_user, _params, session, socket) do
    {:cont, mount_current_user(socket, session)}
  end

  def on_mount(:require_authenticated, _params, session, socket) do
    socket = mount_current_user(socket, session)

    if socket.assigns.current_user do
      {:cont, socket}
    else
      {:halt,
       socket
       |> Phoenix.LiveView.put_flash(:error, "Please authenticate to continue.")
       |> Phoenix.LiveView.redirect(to: "/login")}
    end
  end

  # ── Private ──────────────────────────────────────────────────────────────

  defp mount_current_user(socket, session) do
    user = resolve_user(session["session_id"])
    Phoenix.Component.assign(socket, :current_user, user)
  end

  defp resolve_user(nil), do: nil

  defp resolve_user(session_id) do
    case Repo.get(Session, session_id) do
      %Session{status: "active", expires_at: expires_at, user_id: user_id} ->
        if DateTime.compare(expires_at, DateTime.utc_now()) == :gt do
          resolve_active_user(user_id)
        else
          Logger.info(
            "[UserAuth] Session #{session_id} TTL elapsed — treating as unauthenticated"
          )

          nil
        end

      _ ->
        nil
    end
  end

  defp resolve_active_user(user_id) do
    case Repo.get(User, user_id) do
      %User{status: "active"} = user ->
        user

      %User{status: status} ->
        Logger.info("[UserAuth] User #{user_id} is #{status} — denying access")
        nil

      nil ->
        nil
    end
  end
end
