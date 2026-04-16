defmodule Nexus.Storage do
  @moduledoc """
  Hardened Storage Reset for Nexus Distributed Integration Tests.
  Ensures literal 'Clean Slate' by bypassing triggers and truncating schemas.
  """
  require Logger

  def reset! do
    Logger.info("[Storage] Wiping Test Databases...")

    # Reset EventStore and Repo
    reset_event_store()
    truncate_repo()

    Logger.info("[Storage] Test Environment: IMMACULATE")
  end

  defp reset_event_store do
    # We use a direct connection to bypass App-level supervision
    config = Nexus.EventStore.config()
    schema = config[:schema] || "event_store"

    {:ok, conn} = Postgrex.start_link(config)

    # Absolute Reset: Drop and Re-create schema
    Postgrex.query!(conn, "DROP SCHEMA IF EXISTS \"#{schema}\" CASCADE;", [])
    Postgrex.query!(conn, "CREATE SCHEMA \"#{schema}\";", [])
    EventStore.Storage.Initializer.run!(conn, config)

    GenServer.stop(conn)
  end

  defp truncate_repo do
    # Truncate all tables in public schema except migrations
    Ecto.Adapters.SQL.query!(
      Nexus.Repo,
      """
      DO $$ DECLARE
          r RECORD;
      BEGIN
          FOR r IN (SELECT tablename FROM pg_tables WHERE schemaname = 'public' AND tablename <> 'schema_migrations') LOOP
              EXECUTE 'TRUNCATE TABLE ' || quote_ident(r.tablename) || ' CASCADE';
          END LOOP;
      END $$;
      """,
      []
    )
  end
end
