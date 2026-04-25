defmodule Nexus.Repo.Migrations.CreateMarketingDomain do
  use Ecto.Migration

  def change do
    drop_if_exists(table(:access_requests))

    create table(:marketing_idempotency_keys, primary_key: false) do
      add(:id, :binary_id, primary_key: true)
      add(:command_name, :string, null: false)
      add(:execution_result, :map)
      add(:executed_at, :utc_datetime_usec, null: false)

      timestamps(type: :utc_datetime_usec, inserted_at: :created_at, updated_at: false)
    end

    create table(:marketing_access_requests, primary_key: false) do
      add(:id, :binary_id, primary_key: true)
      add(:email, :string, null: false)
      add(:name, :string, null: false)
      add(:organization, :string, null: false)
      add(:job_title, :string)
      add(:treasury_volume, :string)
      add(:subsidiaries, :string)
      add(:message, :text)
      add(:status, :string, null: false, default: "pending")
      add(:rejection_reason, :text)
      add(:reviewed_by, :string)
      add(:approved_by, :string)
      add(:rejected_by, :string)
      add(:provisioned_user_id, :binary_id)
      add(:provisioned_org_id, :binary_id)

      timestamps(type: :utc_datetime_usec, inserted_at: :created_at)
    end

    create(unique_index(:marketing_access_requests, [:email]))
    create(index(:marketing_access_requests, [:status]))
  end
end
