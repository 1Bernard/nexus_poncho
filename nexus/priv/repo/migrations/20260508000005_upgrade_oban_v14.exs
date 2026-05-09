defmodule Nexus.Repo.Migrations.UpgradeObanV14 do
  use Ecto.Migration

  # No-op: migration 20260508000004 was updated to target version 14 directly,
  # making this upgrade step redundant. Kept so schema_migrations stays consistent
  # on databases that already have this entry recorded.
  def change, do: :ok
end
