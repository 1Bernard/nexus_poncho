defmodule Nexus.Treasury.TreasuryIdempotencyTest do
  @moduledoc """
  Sovereign Audit for Treasury Idempotency.
  Ensures vault commands are deterministic under duplication.
  """
  use Nexus.DataCase

  @moduletag :no_sandbox

  alias Nexus.Treasury.Commands.RegisterVault
  alias Nexus.Treasury.Idempotency.IdempotencyKey
  alias Nexus.Treasury.Projections.Vault

  @tag :idempotency
  test "RegisterVault is idempotent — second dispatch with same causation_id produces no duplicate" do
    vault_id = Uniq.UUID.uuid7()
    org_id = Uniq.UUID.uuid7()
    causation_id = Uniq.UUID.uuid7()

    command = %RegisterVault{
      vault_id: vault_id,
      org_id: org_id,
      name: "Idempotency Vault",
      currency: "EUR",
      bank_name: "Idempotency Bank",
      account_number: "ACC-IDEM-#{vault_id}",
      iban: "DE#{vault_id}",
      provider: "stripe",
      daily_withdrawal_limit: Decimal.new("50000"),
      requires_multi_sig: false
    }

    opts = [causation_id: causation_id]

    # First dispatch — genesis
    assert :ok = Nexus.App.dispatch(command, opts)

    wait_until(fn ->
      case Repo.get(Vault, vault_id) do
        %{status: "active"} -> {:ok, true}
        _ -> {:error, "waiting for vault projection"}
      end
    end)

    wait_until(fn ->
      case Repo.get(IdempotencyKey, causation_id) do
        nil -> {:error, "waiting for idempotency key"}
        key -> {:ok, key}
      end
    end)

    assert %IdempotencyKey{command_name: "RegisterVault"} = Repo.get(IdempotencyKey, causation_id)

    # Second dispatch — echo — aggregate rejects, projector never fires
    assert {:error, :vault_already_exists} = Nexus.App.dispatch(command, opts)

    count = Repo.one(from(v in Vault, where: v.id == ^vault_id, select: count(v.id)))
    assert count == 1
  end

  defp wait_until(fun, retries \\ 10) do
    case fun.() do
      {:ok, val} ->
        val

      {:error, _} when retries > 0 ->
        Process.sleep(100)
        wait_until(fun, retries - 1)

      {:error, reason} ->
        flunk("Wait until failed: #{reason}")
    end
  end
end
