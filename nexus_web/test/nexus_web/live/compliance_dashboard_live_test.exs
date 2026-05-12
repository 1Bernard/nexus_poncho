defmodule NexusWeb.Compliance.DashboardLiveTest do
  @moduledoc """
  Tests for Compliance.DashboardLive authorization guards and UI rendering.
  """
  use NexusWeb.ConnCase

  import Phoenix.LiveViewTest
  import Nexus.Identity.Fixtures

  # ── Mount guards ──────────────────────────────────────────────────────────

  describe "mount authorization" do
    test "redirects to /login when no session exists", %{conn: conn} do
      assert {:error, {:redirect, %{to: "/login"}}} = live(conn, ~p"/compliance")
    end

    test "redirects to /vaults for treasury_analyst", %{conn: conn} do
      user = user_fixture(%{role: "treasury_analyst", status: "active"})
      session = session_fixture(user.user_id, user.org_id)
      conn = init_test_session(conn, %{session_id: session.id})

      assert {:error, {:redirect, %{to: "/vaults"}}} = live(conn, ~p"/compliance")
    end

    test "redirects to /vaults for vault_manager", %{conn: conn} do
      user = user_fixture(%{role: "vault_manager", status: "active"})
      session = session_fixture(user.user_id, user.org_id)
      conn = init_test_session(conn, %{session_id: session.id})

      assert {:error, {:redirect, %{to: "/vaults"}}} = live(conn, ~p"/compliance")
    end

    test "allows compliance_officer", %{conn: conn} do
      user = user_fixture(%{role: "compliance_officer", status: "active"})
      session = session_fixture(user.user_id, user.org_id)
      conn = init_test_session(conn, %{session_id: session.id})

      assert {:ok, _view, html} = live(conn, ~p"/compliance")
      assert html =~ "Compliance Dashboard"
    end

    test "allows org_admin", %{conn: conn} do
      user = user_fixture(%{role: "org_admin", status: "active"})
      session = session_fixture(user.user_id, user.org_id)
      conn = init_test_session(conn, %{session_id: session.id})

      assert {:ok, _view, html} = live(conn, ~p"/compliance")
      assert html =~ "Compliance Dashboard"
    end

    test "allows group_treasurer", %{conn: conn} do
      user = user_fixture(%{role: "group_treasurer", status: "active"})
      session = session_fixture(user.user_id, user.org_id)
      conn = init_test_session(conn, %{session_id: session.id})

      assert {:ok, _view, html} = live(conn, ~p"/compliance")
      assert html =~ "Compliance Dashboard"
    end

    test "allows super_admin platform role", %{conn: conn} do
      user = user_fixture(%{status: "active", platform_role: "super_admin"})
      session = session_fixture(user.user_id, user.org_id)
      conn = init_test_session(conn, %{session_id: session.id})

      assert {:ok, _view, html} = live(conn, ~p"/compliance")
      assert html =~ "Compliance Dashboard"
    end

    test "allows platform_support", %{conn: conn} do
      user = user_fixture(%{status: "active", platform_role: "platform_support"})
      session = session_fixture(user.user_id, user.org_id)
      conn = init_test_session(conn, %{session_id: session.id})

      assert {:ok, _view, html} = live(conn, ~p"/compliance")
      assert html =~ "Compliance Dashboard"
    end
  end

  # ── Dashboard rendering ───────────────────────────────────────────────────

  describe "dashboard rendering" do
    setup %{conn: conn} do
      user = user_fixture(%{role: "compliance_officer", status: "active"})
      session = session_fixture(user.user_id, user.org_id)
      conn = init_test_session(conn, %{session_id: session.id})

      {:ok, conn: conn}
    end

    test "renders all three stats cards", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/compliance")

      assert html =~ "Clean Screenings"
      assert html =~ "Pending Review"
      assert html =~ "Flagged Entities"
    end

    test "renders PEP Screenings section", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/compliance")

      assert html =~ "PEP Screenings"
    end

    test "renders Flagged Access Requests section", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/compliance")

      assert html =~ "Flagged Access Requests"
    end

    test "renders Recent Audit Events section", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/compliance")

      assert html =~ "Recent Audit Events"
    end

    test "renders filter buttons", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/compliance")

      assert html =~ "All"
      assert html =~ "Flagged"
      assert html =~ "Pending"
    end
  end

  # ── Filter interaction ────────────────────────────────────────────────────

  describe "screening filter" do
    setup %{conn: conn} do
      user = user_fixture(%{role: "compliance_officer", status: "active"})
      session = session_fixture(user.user_id, user.org_id)
      conn = init_test_session(conn, %{session_id: session.id})

      {:ok, conn: conn}
    end

    test "default filter is 'all'", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/compliance")

      # The 'All' button is active (has emerald highlight class)
      assert html =~ ~r/bg-emerald-400\/20[^>]*>[\s\n]*All/
    end

    test "clicking Flagged filter activates it", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/compliance")

      html = render_click(view, "filter", %{"status" => "flagged"})

      assert html =~ ~r/bg-emerald-400\/20[^>]*>[\s\n]*Flagged/
    end

    test "clicking Pending filter activates it", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/compliance")

      html = render_click(view, "filter", %{"status" => "pending"})

      assert html =~ ~r/bg-emerald-400\/20[^>]*>[\s\n]*Pending/
    end

    test "clicking All filter reactivates it after switching", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/compliance")

      render_click(view, "filter", %{"status" => "flagged"})
      html = render_click(view, "filter", %{"status" => "all"})

      assert html =~ ~r/bg-emerald-400\/20[^>]*>[\s\n]*All/
    end
  end
end
