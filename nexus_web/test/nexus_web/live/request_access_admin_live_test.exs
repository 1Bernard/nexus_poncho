defmodule NexusWeb.Admin.RequestAccessAdminLiveTest do
  @moduledoc """
  Tests for RequestAccessAdminLive authorization guards.

  These tests cover the platform-role-based access controls added to the
  admin panel — mount-level redirect for non-staff and event-level blocks
  for role-segregated actions (approve is super_admin only).
  """
  use NexusWeb.ConnCase

  import Phoenix.LiveViewTest
  import Nexus.Identity.Fixtures

  # ── Mount guard ──────────────────────────────────────────────────────────

  describe "mount authorization" do
    test "redirects to / when user has no platform_role", %{conn: conn} do
      user = user_fixture(%{status: "active"})
      session = session_fixture(user.user_id, user.org_id)

      conn = init_test_session(conn, %{session_id: session.id})

      assert {:error, {:redirect, %{to: "/"}}} = live(conn, ~p"/admin/access-requests")
    end

    test "redirects to /login when no session exists", %{conn: conn} do
      assert {:error, {:redirect, %{to: "/login"}}} = live(conn, ~p"/admin/access-requests")
    end

    test "allows access for platform_support", %{conn: conn} do
      user = user_fixture(%{status: "active", platform_role: "platform_support"})
      session = session_fixture(user.user_id, user.org_id)

      conn = init_test_session(conn, %{session_id: session.id})

      assert {:ok, _view, html} = live(conn, ~p"/admin/access-requests")
      assert html =~ "Access Requests"
    end

    test "allows access for super_admin", %{conn: conn} do
      user = user_fixture(%{status: "active", platform_role: "super_admin"})
      session = session_fixture(user.user_id, user.org_id)

      conn = init_test_session(conn, %{session_id: session.id})

      assert {:ok, _view, html} = live(conn, ~p"/admin/access-requests")
      assert html =~ "Access Requests"
    end
  end

  # ── Event-level guards ───────────────────────────────────────────────────

  describe "approve_request authorization" do
    test "platform_support cannot approve — super_admin only", %{conn: conn} do
      user = user_fixture(%{status: "active", platform_role: "platform_support"})
      session = session_fixture(user.user_id, user.org_id)

      conn = init_test_session(conn, %{session_id: session.id})

      {:ok, view, _html} = live(conn, ~p"/admin/access-requests")

      html = render_click(view, "approve_request", %{"id" => Uniq.UUID.uuid7()})

      assert html =~ "Unauthorized"
    end

    test "super_admin approve_request is not blocked by the auth guard", %{conn: conn} do
      user = user_fixture(%{status: "active", platform_role: "super_admin"})
      session = session_fixture(user.user_id, user.org_id)

      conn = init_test_session(conn, %{session_id: session.id})

      {:ok, view, _html} = live(conn, ~p"/admin/access-requests")

      # Dispatching without a role set hits the business-logic guard first,
      # not the auth guard — confirms the auth gate is passed.
      html = render_click(view, "approve_request", %{"id" => Uniq.UUID.uuid7()})

      refute html =~ "Unauthorized"
      assert html =~ "Please select a role before approving"
    end
  end

  describe "reject_request authorization" do
    test "platform_support can reach the reject logic (role check passes)", %{conn: conn} do
      user = user_fixture(%{status: "active", platform_role: "platform_support"})
      session = session_fixture(user.user_id, user.org_id)

      conn = init_test_session(conn, %{session_id: session.id})

      {:ok, view, _html} = live(conn, ~p"/admin/access-requests")

      # No reason set — hits business guard, not auth guard.
      html = render_click(view, "reject_request", %{"id" => Uniq.UUID.uuid7()})

      refute html =~ "Unauthorized"
      assert html =~ "Please provide a rejection reason"
    end
  end
end
