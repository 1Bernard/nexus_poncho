defmodule NexusWeb.UserAuthTest do
  @moduledoc """
  Tests for NexusWeb.UserAuth — session resolution and route guards.
  """
  use NexusWeb.ConnCase

  import Phoenix.LiveViewTest
  import Nexus.Identity.Fixtures

  alias NexusWeb.UserAuth

  # ── Session resolution ────────────────────────────────────────────────────

  describe "fetch_current_user/1" do
    test "assigns nil when no session cookie is present", %{conn: conn} do
      conn = conn |> init_test_session(%{}) |> UserAuth.fetch_current_user()
      assert conn.assigns.current_user == nil
    end

    test "assigns nil when session_id does not exist in the DB", %{conn: conn} do
      conn =
        conn
        |> init_test_session(%{session_id: Uniq.UUID.uuid7()})
        |> UserAuth.fetch_current_user()

      assert conn.assigns.current_user == nil
    end

    test "assigns the user for a valid active session", %{conn: conn} do
      user = user_fixture(%{status: "active"})
      session = session_fixture(user.user_id, user.org_id)

      conn =
        conn
        |> init_test_session(%{session_id: session.id})
        |> UserAuth.fetch_current_user()

      assert conn.assigns.current_user.id == user.user_id
    end

    test "assigns nil when the session status is 'expired'", %{conn: conn} do
      user = user_fixture(%{status: "active"})
      now = DateTime.utc_now() |> DateTime.truncate(:microsecond)

      session =
        session_fixture(user.user_id, user.org_id, %{
          status: "expired",
          expires_at: DateTime.add(now, 3600, :second)
        })

      conn =
        conn
        |> init_test_session(%{session_id: session.id})
        |> UserAuth.fetch_current_user()

      assert conn.assigns.current_user == nil
    end

    test "assigns nil when the session TTL has elapsed", %{conn: conn} do
      user = user_fixture(%{status: "active"})
      past = DateTime.utc_now() |> DateTime.add(-3600, :second) |> DateTime.truncate(:microsecond)

      session = session_fixture(user.user_id, user.org_id, %{expires_at: past})

      conn =
        conn
        |> init_test_session(%{session_id: session.id})
        |> UserAuth.fetch_current_user()

      assert conn.assigns.current_user == nil
    end
  end

  # ── Route guards ──────────────────────────────────────────────────────────

  describe "require_authenticated (on_mount guard)" do
    test "redirects to /login when no session exists", %{conn: conn} do
      assert {:error, {:redirect, %{to: "/login"}}} = live(conn, ~p"/vaults")
    end

    test "redirects to /login when session cookie is present but session is expired", %{
      conn: conn
    } do
      user = user_fixture(%{status: "active"})
      past = DateTime.utc_now() |> DateTime.add(-3600, :second) |> DateTime.truncate(:microsecond)
      session = session_fixture(user.user_id, user.org_id, %{expires_at: past})

      conn = init_test_session(conn, %{session_id: session.id})

      assert {:error, {:redirect, %{to: "/login"}}} = live(conn, ~p"/vaults")
    end

    test "allows access to /vaults with a valid active session", %{conn: conn} do
      user = user_fixture(%{status: "active"})
      session = session_fixture(user.user_id, user.org_id)

      conn = init_test_session(conn, %{session_id: session.id})

      assert {:ok, _view, html} = live(conn, ~p"/vaults")
      assert html =~ "Vault"
    end
  end
end
