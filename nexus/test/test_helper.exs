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
  Nexus.Onboarding.ProcessManagers.OnboardingProcessManager
]
|> Enum.each(fn module ->
  case module.start_link() do
    {:ok, _} -> :ok
    {:error, {:already_started, _}} -> :ok
    error -> IO.puts("Failed to start #{module}: #{inspect(error)}")
  end
end)

IO.puts("==> [Nexus] Integration Environment: READY")
