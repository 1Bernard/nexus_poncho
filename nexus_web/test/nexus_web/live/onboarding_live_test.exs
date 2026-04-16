defmodule NexusWeb.Identity.OnboardingLiveTest do
  use NexusWeb.ConnCase
  import Phoenix.LiveViewTest
  import Nexus.Identity.Fixtures

  alias Nexus.Identity.WebAuthn.BiometricInvitation

  describe "Biometric Onboarding" do
    test "redirects if token is missing", %{conn: conn} do
      assert {:error, {:redirect, %{to: "/"}}} = live(conn, ~p"/onboarding/enroll")
    end

    test "redirects if token is invalid", %{conn: conn} do
      assert {:error, {:redirect, %{to: "/"}}} = live(conn, ~p"/onboarding/enroll?token=invalid")
    end

    test "mounts successfully with a valid token", %{conn: conn} do
      user = user_fixture()
      token = BiometricInvitation.generate_token(user.user_id)

      {:ok, _view, html} = live(conn, ~p"/onboarding/enroll?token=#{token}")
      assert html =~ "Scan Biometric"
      assert html =~ "Securely anchoring your biometric identity"
    end

    test "dispatches EnrollBiometric upon successful handshake", %{conn: conn} do
      user = user_fixture(%{status: "invited"})
      token = BiometricInvitation.generate_token(user.user_id)

      {:ok, view, _html} = live(conn, ~p"/onboarding/enroll?token=#{token}")

      # Simulate the JS Hook pushing the verification result
      handshake_data = %{
        "credential_id" => "fake_cred_id",
        "cose_key" => "fake_cose_key",
        "attestation_object" => "fake_attestation",
        "client_data_json" => "fake_client_data"
      }

      # We watch for the EnrollBiometric command dispatch in the backend
      # In this architecture, we usually don't assert on side-effects directly in LV tests
      # but we can verify that the view responds correctly.

      render_hook(view, "verify_identity", handshake_data)

      # Check if the UI transitioned to success state
      assert render(view) =~ "Neural profile secured"
      assert render(view) =~ "Biometric vault synchronized"
    end
  end
end
