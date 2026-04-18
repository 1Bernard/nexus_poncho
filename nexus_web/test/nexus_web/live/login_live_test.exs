defmodule NexusWeb.Identity.LoginLiveTest do
  @moduledoc """
  Tests for the biometric LoginLive.
  The actual WebAuthn assertion path (login_verify) requires real hardware and
  a live challenge store, so it is covered by integration/E2E tests.
  These tests cover: mount state, challenge generation flow, client-side
  error handling, and the retry path.
  """
  use NexusWeb.ConnCase

  import Phoenix.LiveViewTest

  describe "mount" do
    test "renders in idle state", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/login")

      assert html =~ "Biometric Authentication"
      assert html =~ "Scan Fingerprint"
      assert html =~ "Place your enrolled finger"
      assert html =~ "Authenticate"
    end

    test "does not show retry button on initial mount", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/login")

      refute html =~ "Try Again"
    end
  end

  describe "biometric_login_start event" do
    test "transitions to scanning state and pushes a challenge to the client", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/login")

      html = render_click(view, "biometric_login_start")

      assert html =~ "Verifying Identity"
      assert html =~ "Hold still"
    end
  end

  describe "biometric_error event" do
    test "transitions to error state with the hardware message", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/login")

      html = render_hook(view, "biometric_error", %{"reason" => "sensor not responding"})

      assert html =~ "Authentication Failed"
      assert html =~ "Hardware authentication failed: sensor not responding"
      assert html =~ "Try Again"
    end

    test "shows focus-loss guidance when reason contains 'focus'", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/login")

      html = render_hook(view, "biometric_error", %{"reason" => "page lost focus"})

      assert html =~ "Security focus lost"
      assert html =~ "Click the fingerprint scanner directly"
    end
  end

  describe "retry event" do
    test "resets to idle state from error", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/login")

      render_hook(view, "biometric_error", %{"reason" => "timeout"})
      html = render_click(view, "retry")

      assert html =~ "Scan Fingerprint"
      assert html =~ "Authenticate"
      refute html =~ "Try Again"
    end
  end
end
