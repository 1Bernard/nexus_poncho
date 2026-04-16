defmodule Nexus.Application do
  @moduledoc false
  use Application

  @impl true
  def start(_type, _args) do
    # Initialize Mnesia for distributed biometric challenges
    :ok = ensure_mnesia_setup()

    # Load topologies for libcluster if configured
    topologies = Application.get_env(:libcluster, :topologies, [])

    # Gateway Mode (web node): minimal supervision — no Horde, no libcluster.
    # Worker Mode (node1, node2): full Horde cluster for distributed process coordination.
    children =
      if System.get_env("STANDALONE_GATEWAY") == "true" do
        [
          Nexus.Repo,
          Nexus.PromEx,
          Nexus.App,
          Nexus.Telemetry.Heartbeat,
          # Periodically prune expired challenges
          {Task, fn ->
            Stream.interval(:timer.minutes(5))
            |> Enum.each(fn _ -> Nexus.Identity.WebAuthn.AuthChallengeStore.prune_expired() end)
          end}
        ]
      else
        [
          Nexus.Repo,
          Nexus.PromEx,
          {Cluster.Supervisor, [topologies, [name: Nexus.ClusterSupervisor]]},
          {Horde.Registry, [name: Nexus.HordeRegistry, keys: :unique, members: :auto]},
          {Horde.DynamicSupervisor,
           [name: Nexus.HordeSupervisor, strategy: :one_for_one, members: :auto]},
          Nexus.HordeCluster,
          Nexus.App,
          Nexus.Telemetry.Heartbeat,
          # Periodically prune expired challenges
          {Task, fn ->
            Stream.interval(:timer.minutes(5))
            |> Enum.each(fn _ -> Nexus.Identity.WebAuthn.AuthChallengeStore.prune_expired() end)
          end}
        ]
      end

    # Functional Partitioning: each entry is {app_config_key, [modules_to_start]}.
    domain_partitions = [
      {:start_identity_projections, [Nexus.Identity.Projectors.UserProjector]},
      {:start_organization_projections, [Nexus.Organization.Projectors.TenantProjector]},
      {:start_compliance_projections,
       [Nexus.Compliance.Projectors.ScreeningProjector, Nexus.Compliance.Workers.PEPWorker]},
      {:start_accounting_projections, [Nexus.Accounting.Projectors.AccountProjector]},
      {:start_treasury_projections, [Nexus.Treasury.Projectors.VaultProjector]},
      {:start_messaging_projections, [Nexus.Messaging.Producers.EmailDispatcher, Nexus.Messaging.Workers.EmailWorker]},
      {:start_onboarding_pm, [Nexus.Onboarding.ProcessManagers.OnboardingProcessManager]}
    ]

    domain_children =
      domain_partitions
      |> Enum.filter(fn {key, _} -> Application.get_env(:nexus, key, true) end)
      |> Enum.flat_map(fn {_, modules} -> modules end)

    all_children = children ++ domain_children

    # LokiLogger: only started when LOKI_URL is set.
    # Absent in test (no env var) so tests never make outbound HTTP calls.
    loki_children =
      case Application.get_env(:nexus, :loki_url) do
        nil -> []
        loki_url ->
          [{Nexus.LokiLogger, [loki_url: loki_url, app: "nexus", env: to_string(Mix.env())]}]
      end

    opts = [strategy: :one_for_one, name: Nexus.Supervisor, max_restarts: 20, max_seconds: 5]
    Supervisor.start_link(loki_children ++ all_children, opts)
  end

  defp ensure_mnesia_setup do
    # Ensure Mnesia is stopped to create schema if needed
    :mnesia.stop()
    :mnesia.create_schema([node()])
    :mnesia.start()

    # Create table with ram_copies for O(1) performance in a cluster
    table_opts = [
      attributes: [:id, :challenge, :expiry],
      ram_copies: [node()],
      type: :set
    ]

    case :mnesia.create_table(:auth_challenges, table_opts) do
      {:atomic, :ok} -> :ok
      {:aborted, {:already_exists, :auth_challenges}} -> :ok
      {:aborted, reason} ->
        require Logger
        Logger.error("Failed to initialize Mnesia table: #{inspect(reason)}")
        {:error, reason}
    end
  end
end
