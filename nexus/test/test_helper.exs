ExUnit.start(max_cases: 1)

# --- Sovereign Reset Strategy ---
# Projection DB is wiped by the host BEFORE mix test starts.
# The application and EventStore auto-start before this file runs — we
# just ensure they are up and then configure the sandbox.

# 1. Force Commanded timeouts
Application.put_env(:commanded, :assert_receive_event_timeout, 5000)
Application.put_env(:commanded, :refute_receive_event_timeout, 1000)

# 2. Start essential drivers (idempotent if already running)
{:ok, _} = Application.ensure_all_started(:postgrex)
{:ok, _} = Application.ensure_all_started(:ecto_sql)

# 3. Ensure Repo and EventStore are up
case Nexus.Repo.start_link() do
  {:ok, _} -> :ok
  {:error, {:already_started, _}} -> :ok
  _ -> :ok
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
# :auto lets projectors process any EventStore backlog at startup using their own
# connections. DataCase.setup_sandbox then calls Sandbox.allow with
# unallow_existing: true to force-redirect projector checkouts to the test's
# owner connection, making projector writes visible within the test sandbox.
Ecto.Adapters.SQL.Sandbox.mode(Nexus.Repo, :auto)

# 6.5 Reset projection checkpoints so manually-started projectors replay
# from EventStore position 0. Required when the EventStore DB is wiped between
# suite runs but the projection DB is not — stale checkpoint values cause every
# new event to be dropped as "already seen" (event_number < stale_checkpoint).
Ecto.Adapters.SQL.query!(Nexus.Repo, "TRUNCATE TABLE projection_versions", [])

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
