defmodule NexusWeb.Identity.LoginLiveTest do
  @moduledoc """
  Tests for the biometric LoginLive wizard.

  The wizard has four steps: welcome → consent → biometric → success.
  Actual WebAuthn assertion (login_verify) requires real hardware and a live
  challenge store; that path is covered by integration/E2E tests.

  These tests cover: mount state, wizard navigation, biometric challenge
  initiation, client-side error handling, and the retry path.
  """
  use NexusWeb.ConnCase

  import Phoenix.LiveViewTest

  # Navigate the wizard from welcome through to the biometric step.
  defp reach_biometric_step(view) do
    render_click(view, "advance_step")
    render_click(view, "toggle_consent")
    render_click(view, "advance_step")
  end

  describe "mount" do
    test "renders welcome step on initial load", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/login")

      assert html =~ "Institutional"
      assert html =~ "Verification"
      assert html =~ "Authenticate session"
      assert html =~ "SECURE ACCESS"
    end

    test "does not show error state on initial mount", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/login")

      refute html =~ "Hardware authentication failed"
      refute html =~ "Security focus lost"
    end
  end

  describe "wizard navigation" do
    test "advances from welcome to consent step", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/login")

      html = render_click(view, "advance_step")

      assert html =~ "Privacy"
      assert html =~ "data processing notice"
      assert html =~ "GDPR Article 9"
    end

    test "consent button is disabled until checkbox is checked", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/login")

      html = render_click(view, "advance_step")

      assert html =~ "cursor-not-allowed"
      assert html =~ ~s(disabled="")

      html = render_click(view, "toggle_consent")

      refute html =~ "cursor-not-allowed"
      refute html =~ ~s(disabled="")
    end

    test "advances to biometric step after consent is given", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/login")

      html = reach_biometric_step(view)

      assert html =~ "Sensor Calibration"
      assert html =~ "Press &amp; Hold"
      assert html =~ "biometric-sensor"
    end

    test "back_step returns from consent to welcome", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/login")

      render_click(view, "advance_step")
      html = render_click(view, "back_step")

      assert html =~ "Authenticate session"
    end
  end

  describe "biometric_login_start event" do
    test "transitions biometric step to scanning state", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/login")

      reach_biometric_step(view)
      html = render_click(view, "biometric_login_start")

      assert html =~ "AUTHORIZATION PROCESSING"
    end
  end

  describe "biometric_error event" do
    test "shows hardware error inline on the biometric step", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/login")

      reach_biometric_step(view)
      html = render_hook(view, "biometric_error", %{"reason" => "sensor not responding"})

      assert html =~ "Hardware authentication failed: sensor not responding"
    end

    test "shows focus-loss guidance when reason contains 'focus'", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/login")

      reach_biometric_step(view)
      html = render_hook(view, "biometric_error", %{"reason" => "page lost focus"})

      assert html =~ "Security focus lost"
      assert html =~ "Click the sensor directly"
    end
  end

  describe "retry event" do
    test "resets error state back to idle on the biometric step", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/login")

      reach_biometric_step(view)
      render_hook(view, "biometric_error", %{"reason" => "timeout"})
      html = render_click(view, "retry")

      assert html =~ "Sensor Calibration"
      refute html =~ "Hardware authentication failed"
    end
  end
end
