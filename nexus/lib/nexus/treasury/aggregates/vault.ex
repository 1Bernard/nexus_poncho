defmodule Nexus.Treasury.Aggregates.Vault do
  @moduledoc """
  Vault Aggregate.
  The core of the ledger. Handles asset balances, credit/debit limits, and reconciliation.
  Follows Standard: Deterministic Engine.
  """

  defstruct [
    :vault_id,
    :org_id,
    :name,
    :currency,
    :balance,
    :status,
    :bank_name,
    :account_number,
    :iban,
    :provider,
    :daily_withdrawal_limit,
    :requires_multi_sig
  ]

  alias __MODULE__, as: Vault
  alias Nexus.Treasury.Commands.{CreditVault, RegisterVault}
  alias Nexus.Treasury.Events.{VaultCredited, VaultRegistered}

  # --- Command Handlers ---

  def execute(%Vault{vault_id: nil}, %RegisterVault{} = command) do
    %VaultRegistered{
      vault_id: command.vault_id,
      org_id: command.org_id,
      name: command.name,
      currency: command.currency,
      bank_name: command.bank_name,
      account_number: command.account_number,
      iban: command.iban,
      provider: command.provider,
      daily_withdrawal_limit: command.daily_withdrawal_limit,
      requires_multi_sig: command.requires_multi_sig
    }
  end

  def execute(%Vault{} = state, %CreditVault{} = command) do
    if state.status == "active" do
      %VaultCredited{
        vault_id: state.vault_id,
        org_id: command.org_id,
        amount: command.amount,
        transfer_id: command.transfer_id
      }
    else
      {:error, "vault is not active"}
    end
  end

  # --- State Transitions ---

  def apply(%Vault{} = state, %VaultRegistered{} = event) do
    %Vault{
      state
      | vault_id: event.vault_id,
        org_id: event.org_id,
        name: event.name,
        currency: event.currency,
        balance: Decimal.new(0),
        status: "active",
        bank_name: event.bank_name,
        account_number: event.account_number,
        iban: event.iban,
        provider: event.provider,
        daily_withdrawal_limit: event.daily_withdrawal_limit,
        requires_multi_sig: event.requires_multi_sig
    }
  end

  def apply(%Vault{} = state, %VaultCredited{} = event) do
    %Vault{
      state
      | balance: Decimal.add(state.balance || Decimal.new(0), event.amount)
    }
  end
end
