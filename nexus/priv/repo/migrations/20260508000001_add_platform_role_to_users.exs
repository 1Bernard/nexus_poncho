defmodule Nexus.Repo.Migrations.AddPlatformRoleToUsers do
  use Ecto.Migration

  def change do
    alter table(:identity_users) do
      add(:platform_role, :string, null: true)
    end

    create(index(:identity_users, [:platform_role]))
  end
end
