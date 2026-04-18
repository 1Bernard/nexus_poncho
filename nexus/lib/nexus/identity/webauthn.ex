defmodule Nexus.Identity.WebAuthn do
  @moduledoc """
  Defines the behavior for WebAuthn (Biometric Identity) adapters.

  This allows us to swap the real `Wax` implementation for a `Mock` adapter
  during CI/CD and automated testing.
  """

  @callback register_begin(user_id :: String.t(), email :: String.t(), opts :: keyword()) ::
              {:ok, map()} | {:error, term()}

  @callback register_finish(params :: map(), challenge :: binary(), user_id :: binary()) ::
              {:ok, map()} | {:error, term()}

  @callback authenticate_challenge(user_credentials :: list()) ::
              {:ok, map()} | {:error, term()}

  @callback verify_authentication(
              params :: map(),
              challenge :: binary(),
              user_credentials :: list()
            ) ::
              {:ok, map()} | {:error, term()}

  @doc """
  Returns the configured WebAuthn adapter.
  """
  def adapter do
    Application.get_env(:nexus, :webauthn_adapter, Nexus.Identity.WebAuthn.WaxAdapter)
  end

  # Proxy functions to the active adapter

  def register_begin(user_id, email, opts \\ []),
    do: adapter().register_begin(user_id, email, opts)

  def register_finish(params, challenge, user_id),
    do: adapter().register_finish(params, challenge, user_id)

  def authenticate_challenge(user_credentials),
    do: adapter().authenticate_challenge(user_credentials)

  def verify_authentication(params, challenge, user_credentials) do
    adapter().verify_authentication(params, challenge, user_credentials)
  end
end
