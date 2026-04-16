defmodule Nexus.Repo do
  @moduledoc """
  Ecto repository for Nexus. Provides the primary database connection pool
  to the TimescaleDB/PostgreSQL instance.
  """
  use Ecto.Repo,
    otp_app: :nexus,
    adapter: Ecto.Adapters.Postgres

  def generate_uuid_v7, do: Uniq.UUID.uuid7()
end
