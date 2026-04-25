defmodule Nexus.Treasury.VaultLifecycleTest do
  @moduledoc """
  Sovereign Audit for the Vault aggregate.
  Verifies RegisterVault state transitions and read model projections.
  """
  use Nexus.DataCase

  @moduletag :no_sandbox

  alias Nexus.Treasury.Commands.{CreditVault, RegisterVault}
  alias Nexus.Treasury.Projections.Vault

  describe "RegisterVault" do
    test "creates a vault read model in active status with zero balance" do
      {vault_id, org_id} = register_vault()

      vault =
        wait_until(fn ->
          case Repo.get(Vault, vault_id) do
            %{status: "active"} = v -> {:ok, v}
            _ -> {:error, "waiting for vault projection"}
          end
        end)

      assert vault.org_id == org_id
      assert vault.name == "Test Vault"
      assert vault.currency == "USD"
      assert vault.status == "active"
      assert Decimal.equal?(vault.balance, Decimal.new(0))
    end

    test "registering the same vault_id twice is idempotent — read model has one record" do
      vault_id = Uniq.UUID.uuid7()
      org_id = Uniq.UUID.uuid7()
      cmd = build_register_command(vault_id, org_id)

      assert :ok = Nexus.App.dispatch(cmd)

      wait_until(fn ->
        case Repo.get(Vault, vault_id) do
          %{status: "active"} -> {:ok, true}
          _ -> {:error, "waiting for vault"}
        end
      end)

      assert {:error, :vault_already_exists} = Nexus.App.dispatch(cmd)

      count = Repo.one(from(v in Vault, where: v.id == ^vault_id, select: count(v.id)))
      assert count == 1
    end
  end

  describe "CreditVault" do
    test "credits an active vault and updates balance in the read model" do
      {vault_id, org_id} = register_vault()

      wait_until(fn ->
        case Repo.get(Vault, vault_id) do
          %{status: "active"} -> {:ok, true}
          _ -> {:error, "waiting for vault"}
        end
      end)

      :ok =
        Nexus.App.dispatch(%CreditVault{
          vault_id: vault_id,
          org_id: org_id,
          amount: Decimal.new("5000.00"),
          currency: "USD",
          transfer_id: Uniq.UUID.uuid7(),
          credited_at: DateTime.utc_now()
        })

      vault =
        wait_until(fn ->
          case Repo.get(Vault, vault_id) do
            %{balance: balance} = v ->
              if Decimal.gt?(balance, Decimal.new(0)),
                do: {:ok, v},
                else: {:error, "waiting for balance update"}

            _ ->
              {:error, "waiting for balance update"}
          end
        end)

      assert Decimal.equal?(vault.balance, Decimal.new("5000.00"))
    end

    test "crediting an inactive vault is rejected" do
      vault_id = Uniq.UUID.uuid7()
      org_id = Uniq.UUID.uuid7()

      assert {:error, _} =
               Nexus.App.dispatch(%CreditVault{
                 vault_id: vault_id,
                 org_id: org_id,
                 amount: Decimal.new("1000.00"),
                 currency: "USD",
                 transfer_id: Uniq.UUID.uuid7(),
                 credited_at: DateTime.utc_now()
               })
    end
  end

  defp register_vault do
    vault_id = Uniq.UUID.uuid7()
    org_id = Uniq.UUID.uuid7()
    :ok = Nexus.App.dispatch(build_register_command(vault_id, org_id))
    {vault_id, org_id}
  end

  defp build_register_command(vault_id, org_id) do
    %RegisterVault{
      vault_id: vault_id,
      org_id: org_id,
      name: "Test Vault",
      currency: "USD",
      bank_name: "Test Bank",
      account_number: "ACC-#{vault_id}",
      iban: "GB#{vault_id}",
      provider: "modulr",
      daily_withdrawal_limit: Decimal.new("100000"),
      requires_multi_sig: false
    }
  end

  defp wait_until(fun, retries \\ 20) do
    case fun.() do
      {:ok, val} ->
        val

      {:error, _} when retries > 0 ->
        Process.sleep(200)
        wait_until(fun, retries - 1)

      {:error, reason} ->
        flunk(reason)
    end
  end
end
