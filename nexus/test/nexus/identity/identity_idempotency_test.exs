defmodule Nexus.Identity.IdentityIdempotencyTest do
  @moduledoc """
  Sovereign Audit for Identity Idempotency.
  Ensures that the cluster maintains absolute truth even under command duplication.
  """
  use Nexus.DataCase

  alias Nexus.Identity.Commands.RegisterUser
  alias Nexus.Identity.Projections.User
  alias Nexus.Identity.Idempotency.IdempotencyKey

  @tag :idempotency
  test "RegisterUser is deterministic and idempotent" do
    user_id = Uniq.UUID.uuid7()
    org_id = Uniq.UUID.uuid7()
    email = "audit-#{Uniq.UUID.uuid7()}@nexus.com"

    command = %RegisterUser{
      user_id: user_id,
      org_id: org_id,
      email: email,
      name: "Audit User",
      role: "user",
      credential_id: "cred_#{Uniq.UUID.uuid7()}",
      cose_key: "dummy_key_public_cose"
    }

    causation_id = Uniq.UUID.uuid7()
    opts = [causation_id: causation_id]

    # --- Step 1: First Dispatch (The Genesis) ---
    assert {:ok, _result} = Nexus.dispatch(command, opts)

    # Wait for Projection (Extreme Fidelity)
    wait_until(fn ->
      case Repo.get(User, user_id) do
        nil -> {:error, "Still waiting for user projection"}
        user -> {:ok, user}
      end
    end)

    # Verify Read Model exists
    assert %User{email: ^email} = Repo.get(User, user_id)

    # Wait for Idempotency Record
    wait_until(fn ->
      case Repo.get(IdempotencyKey, causation_id) do
        nil -> {:error, "Still waiting for idempotency key: #{causation_id}"}
        key -> {:ok, key}
      end
    end)

    assert %IdempotencyKey{command_name: "RegisterUser"} = Repo.get(IdempotencyKey, causation_id)

    # --- Step 2: Second Dispatch (The Echo) ---
    # We use the EXACT same command and options
    assert {:ok, _result_retried} = Nexus.dispatch(command, opts)

    # Verify NO duplicates
    user_count = Repo.one(from(u in User, where: u.email == ^email, select: count(u.id)))
    assert user_count == 1
  end

  # Elite Helper for Async Projections
  defp wait_until(fun, retries \\ 10) do
    case fun.() do
      {:ok, result} ->
        result

      {:error, _} when retries > 0 ->
        Process.sleep(100)
        wait_until(fun, retries - 1)

      {:error, reason} ->
        flunk("Wait until failed: #{reason}")
    end
  end
end
