defmodule Nexus.Identity.Queries.GetUserByCredentialId do
  @moduledoc """
  Looks up a User read model by their enrolled WebAuthn credential_id.

  Used during biometric login: after the browser returns the WebAuthn assertion,
  the raw credential_id identifies which user is authenticating before the
  cryptographic signature is verified.
  """
  alias Nexus.Identity.Projections.User
  alias Nexus.Repo

  @doc """
  Returns the User projection for the given credential_id, or nil if
  no enrolled user owns this credential.
  """
  @spec execute(binary()) :: User.t() | nil
  def execute(credential_id) when is_binary(credential_id) do
    Repo.get_by(User, credential_id: credential_id)
  end

  def execute(_), do: nil
end
