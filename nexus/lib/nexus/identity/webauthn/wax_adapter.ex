defmodule Nexus.Identity.WebAuthn.WaxAdapter do
  @moduledoc """
  Wax-based implementation of the WebAuthn behavior using Mnesia for storage.
  """
  @behaviour Nexus.Identity.WebAuthn

  alias Nexus.Identity.WebAuthn.AuthChallengeStore

  require Logger

  @impl true
  def register_begin(user_id, email, opts \\ []) do
    origin = opts[:origin] || origin()

    challenge =
      Wax.new_registration_challenge(
        user_id: user_id,
        user_name: email,
        rp_id: rp_id(origin),
        origin: origin
      )

    case AuthChallengeStore.put(user_id, challenge) do
      :ok -> {:ok, challenge}
      {:error, reason} -> {:error, reason}
    end
  end

  @impl true
  def register_finish(params, challenge_id, _user_id) do
    Logger.info("[WaxAdapter] Completing registration for challenge: #{challenge_id}")

    case AuthChallengeStore.get(challenge_id) do
      nil -> {:error, :challenge_not_found_or_expired}
      challenge -> do_register_finish(params, challenge_id, challenge)
    end
  end

  defp do_register_finish(_params, _challenge_id, challenge) when not is_map(challenge) do
    Logger.error("[WaxAdapter] Retrieved challenge is not a map! Got: #{inspect(challenge)}")
    {:error, :invalid_challenge_format}
  end

  defp do_register_finish(params, challenge_id, challenge) do
    # params is the attestation map from JS, which contains a nested "response"
    response = params["response"]
    attestation = Base.decode64!(response["attestationObject"])
    client_data = Base.decode64!(response["clientDataJSON"])

    case Wax.register(attestation, client_data, challenge) do
      {:ok, {authenticator_data, attestation_result}} ->
        AuthChallengeStore.delete(challenge_id)
        # Elite Standard: Extract keys from the AuthenticatorData struct (first element)
        # and return them in a structured map for the UI.
        # The second element (attestation_result) can be {:self, nil, nil} for self-attestation.
        {:ok,
         %{
           authenticator_data: authenticator_data,
           auth_data: %{
             credential_id: authenticator_data.attested_credential_data.credential_id,
             cose_key: authenticator_data.attested_credential_data.credential_public_key
           },
           attestation_result: attestation_result
         }}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @impl true
  def authenticate_challenge(user_credentials) do
    origin = origin()

    challenge =
      Wax.new_authentication_challenge(
        rp_id: rp_id(origin),
        origin: origin,
        allow_credentials: user_credentials
      )

    # Since authentication might not have a user_id yet (if using discovery),
    # we use the challenge itself as the lookup key.
    challenge_id = Base.encode64(challenge.bytes)

    case AuthChallengeStore.put(challenge_id, challenge) do
      :ok -> {:ok, challenge}
      {:error, reason} -> {:error, reason}
    end
  end

  @impl true
  def verify_authentication(params, challenge_id, user_credentials) do
    case AuthChallengeStore.get(challenge_id) do
      nil -> {:error, :challenge_not_found_or_expired}
      challenge -> do_verify_authentication(params, challenge_id, user_credentials, challenge)
    end
  end

  defp do_verify_authentication(_params, _challenge_id, _user_credentials, challenge)
       when not is_map(challenge) do
    Logger.error("[WaxAdapter] Retrieved challenge is not a map! Got: #{inspect(challenge)}")
    {:error, :invalid_challenge_format}
  end

  defp do_verify_authentication(params, challenge_id, user_credentials, challenge) do
    response = params["response"]
    raw_id = Base.decode64!(params["rawId"])
    auth_data = Base.decode64!(response["authenticatorData"])
    signature = Base.decode64!(response["signature"])
    client_data = Base.decode64!(response["clientDataJSON"])

    case Wax.authenticate(raw_id, auth_data, signature, client_data, challenge, user_credentials) do
      {:ok, authenticator} ->
        AuthChallengeStore.delete(challenge_id)
        {:ok, authenticator}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp origin do
    default_origin = Application.get_env(:nexus, :web_host, "http://localhost:4000")

    # Elite Standard: Support both HAProxy gateway (4000) and direct web node (4001)
    # during development to prevent :origin_mismatch errors.
    [String.trim_trailing(default_origin, "/"), "http://localhost:4001"]
  end

  defp rp_id(origin) when is_list(origin) do
    rp_id(List.first(origin))
  end

  defp rp_id(origin) when is_binary(origin) do
    # Trim trailing slash if accidentally passed from dynamic origin detection
    origin = String.trim_trailing(origin, "/")
    uri = URI.parse(origin)
    uri.host || "localhost"
  end
end
