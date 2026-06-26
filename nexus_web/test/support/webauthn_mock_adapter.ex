defmodule Nexus.Identity.WebAuthn.MockAdapter do
  @moduledoc false
  @behaviour Nexus.Identity.WebAuthn

  @impl true
  def authenticate_challenge(_user_credentials) do
    {:ok, %{bytes: :crypto.strong_rand_bytes(32)}}
  end

  @impl true
  def verify_authentication(_params, _challenge_id, _user_credentials) do
    {:ok, %{}}
  end

  @impl true
  def register_begin(_user_id, _email, _opts) do
    {:ok, %{}}
  end

  @impl true
  def register_finish(_params, _challenge, _user_id) do
    {:ok, %{credential_id: "mock_credential_id", cose_key: "mock_cose_key"}}
  end
end
