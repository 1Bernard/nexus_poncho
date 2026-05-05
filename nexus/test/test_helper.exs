ExUnit.start(max_cases: 1)

# --- Sovereign Reset Strategy ---
# Projection DB is wiped by the host BEFORE mix test starts.
# The application and EventStore auto-start before this file runs — we
# stop any projectors first, reset both stores, then restart everything
# fresh so projectors subscribe from position 0 with clean checkpoints.

# 1. Force Commanded timeouts
Application.put_env(:commanded, :assert_receive_event_timeout, 5000)
Application.put_env(:commanded, :refute_receive_event_timeout, 1000)

# 2. Start essential drivers (idempotent if already running)
{:ok, _} = Application.ensure_all_started(:postgrex)
{:ok, _} = Application.ensure_all_started(:ecto_sql)

# 3. Ensure Repo is up
case Nexus.Repo.start_link() do
  {:ok, _} -> :ok
  {:error, {:already_started, _}} -> :ok
  _ -> :ok
end

# 3b. Stop any already-running projectors so they don't hold stale
# EventStore subscriptions through the DB reset below.
[
  Nexus.Accounting.Projectors.AccountProjector,
  Nexus.Identity.Projectors.UserProjector,
  Nexus.Identity.Projectors.SessionProjector,
  Nexus.Identity.Projectors.AuditLogProjector,
  Nexus.Organization.Projectors.TenantProjector,
  Nexus.Treasury.Projectors.VaultProjector,
  Nexus.Compliance.Projectors.ScreeningProjector,
  Nexus.Compliance.Workers.PEPWorker,
  Nexus.Onboarding.ProcessManagers.OnboardingProcessManager,
  Nexus.Audit.Projectors.PlatformAuditProjector
]
|> Enum.each(fn module ->
  case Process.whereis(module) do
    nil -> :ok
    pid -> GenServer.stop(pid, :normal, 5000)
  end
end)

# 3c. Reset EventStore BEFORE starting it — events persist across runs in
# their own DB. Without this reset, projectors replay accumulated events
# on startup, exhausting the connection pool before tests begin.
event_store_config =
  Application.get_env(:nexus, Nexus.EventStore)
  |> Keyword.put_new(:schema, "event_store")

case Postgrex.start_link(event_store_config) do
  {:ok, reset_conn} ->
    try do
      EventStore.Storage.Initializer.reset!(reset_conn, event_store_config)
    rescue
      _ -> EventStore.Storage.Initializer.run!(reset_conn, event_store_config)
    end

    GenServer.stop(reset_conn)

  {:error, reason} ->
    IO.puts("==> [EventStore] Reset skipped — could not connect: #{inspect(reason)}")
end

case Nexus.EventStore.start_link() do
  {:ok, _} -> :ok
  {:error, {:already_started, _}} -> :ok
  _ -> :ok
end

# 4. Final Migration check (just in case)
path = Application.app_dir(:nexus, "priv/repo/migrations")
Ecto.Migrator.run(Nexus.Repo, path, :up, all: true)

# 5. Start the full application
{:ok, _} = Application.ensure_all_started(:commanded)

# 6. Configure Sandbox
Ecto.Adapters.SQL.Sandbox.mode(Nexus.Repo, :auto)

# 6.5 Full projection DB reset before the suite.
# Truncates all projection tables (including checkpoints) so projectors start
# from event position 0. Required when the EventStore DB is wiped between suite
# runs but the projection DB is not — stale checkpoints cause events to be
# silently dropped as "already seen".
%{rows: rows} =
  Ecto.Adapters.SQL.query!(
    Nexus.Repo,
    "SELECT tablename FROM pg_tables WHERE schemaname = 'public' AND tablename != 'schema_migrations'",
    []
  )

rows
|> Enum.map(fn [t] -> ~s("#{t}") end)
|> then(fn tables ->
  if tables != [] do
    Ecto.Adapters.SQL.query!(
      Nexus.Repo,
      "TRUNCATE #{Enum.join(tables, ", ")} RESTART IDENTITY CASCADE",
      []
    )
  end
end)

# 7. Start Domain Side-Effects & Projectors for Integration Testing
IO.puts("==> [Nexus] Starting Domain Projections and Side-Effects...")

[
  Nexus.Accounting.Projectors.AccountProjector,
  Nexus.Identity.Projectors.UserProjector,
  Nexus.Identity.Projectors.SessionProjector,
  Nexus.Identity.Projectors.AuditLogProjector,
  Nexus.Organization.Projectors.TenantProjector,
  Nexus.Treasury.Projectors.VaultProjector,
  Nexus.Compliance.Projectors.ScreeningProjector,
  Nexus.Compliance.Workers.PEPWorker,
  Nexus.Onboarding.ProcessManagers.OnboardingProcessManager,
  Nexus.Audit.Projectors.PlatformAuditProjector
]
|> Enum.each(fn module ->
  case module.start_link() do
    {:ok, _} -> :ok
    {:error, {:already_started, _}} -> :ok
    error -> IO.puts("Failed to start #{module}: #{inspect(error)}")
  end
end)

IO.puts("==> [Nexus] Integration Environment: READY")
