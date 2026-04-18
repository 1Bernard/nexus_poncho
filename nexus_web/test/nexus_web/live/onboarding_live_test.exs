defmodule NexusWeb.Identity.OnboardingLiveTest do
  use NexusWeb.ConnCase

  import Phoenix.LiveViewTest
  import Nexus.Identity.Fixtures

  alias Nexus.Identity.WebAuthn.BiometricInvitation

  describe "token validation" do
    test "redirects to / when token param is missing", %{conn: conn} do
      assert {:error, {:redirect, %{to: "/"}}} = live(conn, ~p"/onboarding/enroll")
    end

    test "redirects to / when token is invalid", %{conn: conn} do
      assert {:error, {:redirect, %{to: "/"}}} =
               live(conn, ~p"/onboarding/enroll?token=not_a_real_token")
    end
  end

  describe "mount with valid token" do
    test "renders the biometric enrollment UI for a projected user", %{conn: conn} do
      user = user_fixture()
      token = BiometricInvitation.generate_token(user.user_id)

      {:ok, _view, html} = live(conn, ~p"/onboarding/enroll?token=#{token}")

      assert html =~ "Secure Enrollment"
      assert html =~ "Securely anchoring your biometric identity"
      assert html =~ "Scan Biometric"
      assert html =~ "Enroll Biometrics"
    end

    test "shows loading state when user projection is not yet in the DB", %{conn: conn} do
      # A token for a user_id with no DB row simulates the projection race condition.
      ghost_user_id = Uniq.UUID.uuid7()
      token = BiometricInvitation.generate_token(ghost_user_id)

      {:ok, _view, html} = live(conn, ~p"/onboarding/enroll?token=#{token}")

      # Must render the loading state — not crash, not hard-redirect.
      assert html =~ "Secure Enrollment"
      assert html =~ "Preparing Identity"
    end
  end

  describe "biometric_error event" do
    test "transitions to error state with a clean message", %{conn: conn} do
      user = user_fixture()
      token = BiometricInvitation.generate_token(user.user_id)

      {:ok, view, _html} = live(conn, ~p"/onboarding/enroll?token=#{token}")

      html = render_hook(view, "biometric_error", %{"reason" => "hardware error: sensor timeout"})

      assert html =~ "Handshake Aborted"
      assert html =~ "Handshake failed: hardware error: sensor timeout"
    end

    test "shows focus-loss guidance when reason contains 'focus'", %{conn: conn} do
      user = user_fixture()
      token = BiometricInvitation.generate_token(user.user_id)

      {:ok, view, _html} = live(conn, ~p"/onboarding/enroll?token=#{token}")

      html = render_hook(view, "biometric_error", %{"reason" => "document lost focus"})

      assert html =~ "Security focus lost"
      assert html =~ "click the fingerprint scanner directly"
    end
  end
end
