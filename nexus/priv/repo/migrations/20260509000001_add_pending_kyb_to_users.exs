defmodule Nexus.Repo.Migrations.AddPendingKybToUsers do
  use Ecto.Migration

  def change do
    alter table(:identity_users) do
      add :terms_accepted_at, :utc_datetime_usec, null: true
      add :terms_version, :string, null: true
    end
  end
end
