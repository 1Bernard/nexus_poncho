defmodule NexusWeb.Identity.TeamManagementLiveTest do
  @moduledoc """
  Tests for TeamManagementLive authorization guards and UI behaviour.

  Command dispatch (DeactivateUser, UpdateUserRole) is covered by domain
  integration tests. These tests cover access control and LiveView state machines
  (modal open/close) that require no EventStore interaction.
  """
  use NexusWeb.ConnCase

  import Phoenix.LiveViewTest
  import Nexus.Identity.Fixtures

  # ── Mount guards ──────────────────────────────────────────────────────────

  describe "mount authorization" do
    test "redirects to /login when no session exists", %{conn: conn} do
      assert {:error, {:redirect, %{to: "/login"}}} = live(conn, ~p"/team")
    end

    test "redirects to /vaults for treasury_analyst", %{conn: conn} do
      user = user_fixture(%{role: "treasury_analyst", status: "active"})
      session = session_fixture(user.user_id, user.org_id)
      conn = init_test_session(conn, %{session_id: session.id})

      assert {:error, {:redirect, %{to: "/vaults"}}} = live(conn, ~p"/team")
    end

    test "redirects to /vaults for auditor", %{conn: conn} do
      user = user_fixture(%{role: "auditor", status: "active"})
      session = session_fixture(user.user_id, user.org_id)
      conn = init_test_session(conn, %{session_id: session.id})

      assert {:error, {:redirect, %{to: "/vaults"}}} = live(conn, ~p"/team")
    end

    test "allows org_admin", %{conn: conn} do
      user = user_fixture(%{role: "org_admin", status: "active"})
      session = session_fixture(user.user_id, user.org_id)
      conn = init_test_session(conn, %{session_id: session.id})

      assert {:ok, _view, html} = live(conn, ~p"/team")
      assert html =~ "Team Management"
    end

    test "allows group_treasurer", %{conn: conn} do
      user = user_fixture(%{role: "group_treasurer", status: "active"})
      session = session_fixture(user.user_id, user.org_id)
      conn = init_test_session(conn, %{session_id: session.id})

      assert {:ok, _view, html} = live(conn, ~p"/team")
      assert html =~ "Team Management"
    end

    test "allows super_admin platform role", %{conn: conn} do
      user = user_fixture(%{status: "active", platform_role: "super_admin"})
      session = session_fixture(user.user_id, user.org_id)
      conn = init_test_session(conn, %{session_id: session.id})

      assert {:ok, _view, html} = live(conn, ~p"/team")
      assert html =~ "Team Management"
    end

    test "allows platform_support", %{conn: conn} do
      user = user_fixture(%{status: "active", platform_role: "platform_support"})
      session = session_fixture(user.user_id, user.org_id)
      conn = init_test_session(conn, %{session_id: session.id})

      assert {:ok, _view, html} = live(conn, ~p"/team")
      assert html =~ "Team Management"
    end
  end

  # ── Member list rendering ─────────────────────────────────────────────────

  describe "member list" do
    setup %{conn: conn} do
      org_id = Uniq.UUID.uuid7()
      admin = user_fixture(%{role: "org_admin", status: "active", org_id: org_id})
      member = user_fixture(%{role: "treasury_analyst", status: "active", org_id: org_id})
      session = session_fixture(admin.user_id, org_id)
      conn = init_test_session(conn, %{session_id: session.id})

      {:ok, conn: conn, admin: admin, member: member}
    end

    test "renders member names from the same org", %{conn: conn, admin: admin, member: member} do
      {:ok, _view, html} = live(conn, ~p"/team")

      assert html =~ admin.name
      assert html =~ member.name
    end

    test "renders member roles", %{conn: conn, member: member} do
      {:ok, _view, html} = live(conn, ~p"/team")

      assert html =~ member.role
    end

    test "shows You label on the current user's row", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/team")

      assert html =~ "You"
    end

    test "shows Invite Member link", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/team")

      assert html =~ "Invite Member"
    end

    test "member count reflects loaded members", %{conn: conn, member: _member} do
      {:ok, _view, html} = live(conn, ~p"/team")

      assert html =~ "active member"
    end
  end

  # ── Deactivation modal state machine ──────────────────────────────────────

  describe "deactivation modal" do
    setup %{conn: conn} do
      org_id = Uniq.UUID.uuid7()
      admin = user_fixture(%{role: "org_admin", status: "active", org_id: org_id})
      member = user_fixture(%{role: "treasury_analyst", status: "active", org_id: org_id})
      session = session_fixture(admin.user_id, org_id)
      conn = init_test_session(conn, %{session_id: session.id})

      {:ok, conn: conn, admin: admin, member: member}
    end

    test "clicking deactivate button opens confirmation modal", %{
      conn: conn,
      member: member
    } do
      {:ok, view, _html} = live(conn, ~p"/team")

      html = render_click(view, "request_deactivate", %{"user_id" => member.user_id})

      assert html =~ "Deactivate Member"
      assert html =~ member.name
    end

    test "cancel dismisses the modal", %{conn: conn, member: member} do
      {:ok, view, _html} = live(conn, ~p"/team")

      render_click(view, "request_deactivate", %{"user_id" => member.user_id})
      html = render_click(view, "cancel_deactivate", %{})

      refute html =~ "Deactivate Member"
    end
  end

  # ── Role change modal state machine ───────────────────────────────────────

  describe "role change modal" do
    setup %{conn: conn} do
      org_id = Uniq.UUID.uuid7()
      admin = user_fixture(%{role: "org_admin", status: "active", org_id: org_id})
      member = user_fixture(%{role: "treasury_analyst", status: "active", org_id: org_id})
      session = session_fixture(admin.user_id, org_id)
      conn = init_test_session(conn, %{session_id: session.id})

      {:ok, conn: conn, admin: admin, member: member}
    end

    test "clicking edit button opens role change modal", %{conn: conn, member: member} do
      {:ok, view, _html} = live(conn, ~p"/team")

      html = render_click(view, "open_role_change", %{"user_id" => member.user_id})

      assert html =~ "Change Role"
      assert html =~ member.name
    end

    test "cancel dismisses the role change modal", %{conn: conn, member: member} do
      {:ok, view, _html} = live(conn, ~p"/team")

      render_click(view, "open_role_change", %{"user_id" => member.user_id})
      html = render_click(view, "cancel_role_change", %{})

      refute html =~ "Change Role"
    end

    test "role select renders available roles", %{conn: conn, member: member} do
      {:ok, view, _html} = live(conn, ~p"/team")

      html = render_click(view, "open_role_change", %{"user_id" => member.user_id})

      assert html =~ "treasury_analyst"
      assert html =~ "vault_manager"
    end
  end
end
