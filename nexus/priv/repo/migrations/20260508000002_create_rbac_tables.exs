defmodule Nexus.Repo.Migrations.CreateRbacTables do
  use Ecto.Migration

  def change do
    # Static role definitions — seeded, not user-editable
    create table(:roles, primary_key: false) do
      add(:id, :binary_id, primary_key: true)
      add(:name, :string, null: false)
      add(:plane, :string, null: false)
      add(:scope, :string, null: false)

      timestamps(type: :utc_datetime_usec, inserted_at: :created_at, updated_at: false)
    end

    create(unique_index(:roles, [:name]))

    # User ↔ role assignments (org-scoped)
    create table(:user_roles, primary_key: false) do
      add(:id, :binary_id, primary_key: true)
      add(:user_id, references(:identity_users, type: :binary_id, on_delete: :delete_all), null: false)
      add(:role_id, references(:roles, type: :binary_id), null: false)
      add(:org_id, :binary_id, null: true)
      add(:subsidiary_id, :binary_id, null: true)
      add(:granted_by, :binary_id, null: false)
      add(:expires_at, :utc_datetime_usec, null: true)

      timestamps(type: :utc_datetime_usec, inserted_at: :created_at, updated_at: false)
    end

    create(index(:user_roles, [:user_id]))
    create(index(:user_roles, [:org_id]))
    create(unique_index(:user_roles, [:user_id, :role_id, :org_id, :subsidiary_id]))

    # Fine-grained entity-level permissions (vault_manager assignments)
    create table(:entity_permissions, primary_key: false) do
      add(:id, :binary_id, primary_key: true)
      add(:user_id, references(:identity_users, type: :binary_id, on_delete: :delete_all), null: false)
      add(:entity_type, :string, null: false)
      add(:entity_id, :binary_id, null: false)
      add(:permission, :string, null: false)
      add(:granted_by, :binary_id, null: false)

      timestamps(type: :utc_datetime_usec, inserted_at: :created_at, updated_at: false)
    end

    create(index(:entity_permissions, [:user_id, :entity_type, :entity_id]))

    # Pending maker-checker approval requests
    create table(:approval_requests, primary_key: false) do
      add(:id, :binary_id, primary_key: true)
      add(:operation_type, :string, null: false)
      add(:payload, :map, null: false)
      add(:requested_by, references(:identity_users, type: :binary_id), null: false)
      add(:org_id, :binary_id, null: false)
      add(:required_role, :string, null: false)
      add(:required_count, :integer, null: false, default: 1)
      add(:approved_count, :integer, null: false, default: 0)
      add(:status, :string, null: false, default: "pending")
      add(:expires_at, :utc_datetime_usec, null: false)

      timestamps(type: :utc_datetime_usec, inserted_at: :created_at)
    end

    create(index(:approval_requests, [:status], where: "status = 'pending'"))
    create(index(:approval_requests, [:org_id]))
    create(index(:approval_requests, [:requested_by]))

    # Individual checker grants (each checker's biometric signature)
    create table(:approval_grants, primary_key: false) do
      add(:id, :binary_id, primary_key: true)
      add(:approval_request_id, references(:approval_requests, type: :binary_id), null: false)
      add(:granted_by, references(:identity_users, type: :binary_id), null: false)
      add(:webauthn_assertion, :map, null: false)

      timestamps(type: :utc_datetime_usec, inserted_at: :created_at, updated_at: false)
    end

    create(index(:approval_grants, [:approval_request_id]))
  end
end
