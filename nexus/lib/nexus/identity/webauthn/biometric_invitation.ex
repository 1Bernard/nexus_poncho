defmodule Nexus.Identity.WebAuthn.BiometricInvitation do
  @moduledoc """
  Secure token generation and verification for biometric enrollment invitations.
  Uses Plug.Crypto for signed, time-limited magic links.

  Standard: Sovereign Identity Sovereignty (Decoupled from Web layer).
  """

  @salt "biometric_invitation"
  # 24 hours
  @max_age 86_400

  @doc """
  Generates a secure token for a user invitation.
  """
  def generate_token(user_id) do
    secret = get_secret()
    Plug.Crypto.sign(secret, @salt, user_id)
  end

  @doc """
  Verifies an invitation token and returns the user_id.
  """
  def verify_token(token) do
    secret = get_secret()

    case Plug.Crypto.verify(secret, @salt, token, max_age: @max_age) do
      {:ok, user_id} -> {:ok, user_id}
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Constructs the magic link for the given token.
  """
  def magic_link(token, opts \\ []) do
    host = opts[:base_url] || Application.get_env(:nexus, :web_host, "http://localhost:4000")
    # Ensure no trailing slash on host for consistency
    host = String.trim_trailing(host, "/")
    "#{host}/onboarding/enroll?token=#{token}"
  end

  defp get_secret do
    Application.fetch_env!(:nexus, :token_secret_key_base)
  end
end
