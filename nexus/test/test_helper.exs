ExUnit.start(max_cases: 1)

# --- Sovereign Reset Strategy ---
# Database is wiped and setup from the host BEFORE mix test starts.
# This eliminates start-up race conditions.

# 1. Force Commanded timeouts
Application.put_env(:commanded, :assert_receive_event_timeout, 5000)
Application.put_env(:commanded, :refute_receive_event_timeout, 1000)

# 2. Start essential drivers
{:ok, _} = Application.ensure_all_started(:postgrex)
{:ok, _} = Application.ensure_all_started(:ecto_sql)

# 3. Start Repo and EventStore
case Nexus.Repo.start_link() do
  {:ok, _} -> :ok
  {:error, {:already_started, _}} -> :ok
  _ -> :ok
end

# 3b. Reset EventStore BEFORE starting it — projection DB is wiped by the host
# before mix test runs, but EventStore events persist across runs in its own DB.
# Without this reset, projectors replay thousands of accumulated events on startup,
# exhausting the connection pool before the first test begins.
# `:schema` is set in config.exs but test.exs replaces the EventStore config entirely,
# so we pin it here explicitly before using the initializer.
event_store_config =
  Application.get_env(:nexus, Nexus.EventStore)
  |> Keyword.put_new(:schema, "event_store")

case Postgrex.start_link(event_store_config) do
  {:ok, reset_conn} ->
    try do
      EventStore.Storage.Initializer.reset!(reset_conn, event_store_config)
    rescue
      # Tables don't exist yet (first boot) — initialize the schema instead
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

# 7. Start Domain Side-Effects & Projectors for Integration Testing
IO.puts("==> [Nexus] Starting Domain Projections and Side-Effects...")

[
  Nexus.Accounting.Projectors.AccountProjector,
  Nexus.Identity.Projectors.UserProjector,
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
