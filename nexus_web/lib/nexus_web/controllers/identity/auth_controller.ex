defmodule NexusWeb.Identity.AuthController do
  @moduledoc """
  Finalises a biometric login by exchanging a short-lived signed token
  (produced by LoginLive) for a durable Phoenix session cookie.

  This indirection exists because LiveView cannot set session cookies directly —
  only a controller plug can write to the conn session.
  """
  use NexusWeb, :controller

  alias Nexus.Identity.Commands.ExpireSession
  alias Nexus.Identity.Projections.Session
  alias Nexus.Repo
  alias NexusWeb.UserAuth

  require Logger

  # Token is valid for 30 seconds — single-use bridge from LiveView to controller
  @token_max_age 30

  @doc """
  Receives the auth token from LoginLive, verifies it, writes the session_id
  cookie, and redirects to the dashboard.
  """
  def finalise(conn, %{"token" => token}) do
    case Phoenix.Token.verify(NexusWeb.Endpoint, "session_auth", token, max_age: @token_max_age) do
      {:ok, session_id} ->
        await_session_projection(session_id)

        conn
        |> put_session(:session_id, session_id)
        |> redirect(to: "/vaults")

      {:error, reason} ->
        Logger.warning("[AuthController] Auth token rejected: #{inspect(reason)}")

        conn
        |> put_flash(:error, "Authentication link expired. Please try again.")
        |> redirect(to: "/login")
    end
  end

  @doc """
  Logs the user out: expires the domain session, clears the cookie, redirects to /login.
  """
  def logout(conn, _params) do
    session_id = get_session(conn, :session_id)
    current_user = conn.assigns[:current_user]

    if session_id && current_user do
      Nexus.App.dispatch(%ExpireSession{
        session_id: session_id,
        user_id: current_user.id,
        org_id: current_user.org_id
      })
    end

    conn
    |> UserAuth.log_out()
    |> redirect(to: "/login")
  end

  # SessionProjector is asynchronous — the session row may not exist in the
  # read model by the time the browser hits /vaults. Poll until it appears
  # (up to 2s) so require_authenticated never races against the projector.
  defp await_session_projection(session_id, retries \\ 20) do
    case Repo.get(Session, session_id) do
      nil when retries > 0 ->
        Process.sleep(100)
        await_session_projection(session_id, retries - 1)

      _ ->
        :ok
    end
  end
end
