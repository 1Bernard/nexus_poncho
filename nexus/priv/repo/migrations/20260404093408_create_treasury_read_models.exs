defmodule Nexus.Repo.Migrations.CreateTreasuryReadModels do
  @moduledoc """
  Migration for Treasury read models, audit logs, and idempotency keys.
  Follows Standard Chapter 3: Database Schema & Professional Standards.
  """
  use Ecto.Migration

  def change do
    # Treasury Vaults (Read Model)
    create table(:treasury_vaults, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :org_id, :binary_id, null: false
      add :name, :string, null: false
      add :bank_name, :string, null: false
      add :account_number, :string, null: false
      add :iban, :string
      add :currency, :string, null: false
      add :balance, :decimal, precision: 20, scale: 4, default: 0, null: false
      add :provider, :string, null: false
      add :status, :string, default: "active", null: false
      add :daily_withdrawal_limit, :decimal, precision: 20, scale: 4, default: 0, null: false
      add :requires_multi_sig, :boolean, default: false, null: false

      timestamps(type: :utc_datetime_usec, inserted_at: :created_at)
    end

    create_if_not_exists index(:treasury_vaults, [:org_id])

    # Treasury Audit Logs (Standard Chapter 18)
    create table(:treasury_audit_logs, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :event_id, :binary_id, null: false
      add :org_id, :binary_id, null: false
      add :event_type, :string, null: false
      add :payload, :map, null: false
      add :recorded_at, :utc_datetime_usec, null: false
      add :signature, :string

      timestamps(type: :utc_datetime_usec, inserted_at: :created_at)
    end

    create_if_not_exists index(:treasury_audit_logs, [:org_id])

    # Treasury Idempotency Keys (Standard Chapter 8)
    create table(:treasury_idempotency_keys, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :command_name, :string, null: false
      add :execution_result, :map
      add :executed_at, :utc_datetime_usec, null: false

      timestamps(type: :utc_datetime_usec, inserted_at: :created_at)
    end
  end
end
