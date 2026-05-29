defmodule Nexus.Application do
  @moduledoc false
  use Application

  alias Nexus.Identity.WebAuthn.AuthChallengeStore

  @impl true
  def start(_type, _args) do
    # Attach Ecto telemetry → OTel spans. Called once here so it covers both
    # worker nodes (nexus is the top-level app) and the web node (nexus is a dep).
    if Code.ensure_loaded?(OpentelemetryEcto) do
      OpentelemetryEcto.setup([:nexus, :repo])
    end

    # Initialize Mnesia for distributed biometric challenges
    :ok = ensure_mnesia_setup()

    # Load topologies for libcluster if configured
    topologies = Application.get_env(:libcluster, :topologies, [])

    # Gateway Mode (web node): minimal supervision — no Horde, no libcluster.
    # Worker Mode (node1, node2): full Horde cluster for distributed process coordination.
    children =
      if System.get_env("STANDALONE_GATEWAY") == "true" do
        [
          Nexus.PromEx,
          Nexus.Repo,
          Nexus.App,
          Nexus.Telemetry.Heartbeat,
          # Periodically prune expired challenges
          {Task,
           fn ->
             Stream.interval(:timer.minutes(5))
             |> Enum.each(fn _ -> AuthChallengeStore.prune_expired() end)
           end}
        ]
      else
        [
          Nexus.PromEx,
          Nexus.Repo,
          {Oban, Application.fetch_env!(:nexus, Oban)},
          {Cluster.Supervisor, [topologies, [name: Nexus.ClusterSupervisor]]},
          {Horde.Registry, [name: Nexus.HordeRegistry, keys: :unique, members: :auto]},
          {Horde.DynamicSupervisor,
           [
             name: Nexus.HordeSupervisor,
             strategy: :one_for_one,
             members: :auto,
             delta_crdt_options: [sync_interval: 200]
           ]},
          Nexus.HordeCluster,
          Nexus.App,
          # Broadway RabbitMQ consumer — intentionally NOT in Horde.
          # Multiple instances across nodes increases email throughput.
          Nexus.Messaging.Workers.EmailWorker,
          # All other projectors/handlers/process managers — one per module globally.
          Nexus.ProjectionCoordinator,
          Nexus.Telemetry.Heartbeat,
          {Task,
           fn ->
             Stream.interval(:timer.minutes(5))
             |> Enum.each(fn _ -> AuthChallengeStore.prune_expired() end)
           end}
        ]
      end

    all_children = children

    # LokiLogger: only started when LOKI_URL is set.
    # Absent in test (no env var) so tests never make outbound HTTP calls.
    loki_children =
      case Application.get_env(:nexus, :loki_url) do
        nil ->
          []

        loki_url ->
          [{Nexus.LokiLogger, [loki_url: loki_url, app: "nexus", env: to_string(Mix.env())]}]
      end

    opts = [strategy: :one_for_one, name: Nexus.Supervisor, max_restarts: 20, max_seconds: 5]
    Supervisor.start_link(loki_children ++ all_children, opts)
  end

  defp ensure_mnesia_setup do
    # Use /tmp so Mnesia disk I/O stays on fast container-local storage.
    # Auth challenges are ephemeral — disk persistence has no value, and
    # writing through virtiofs (macOS dev mount) causes multi-minute shutdown hangs.
    Application.put_env(:mnesia, :dir, ~c"/tmp/mnesia")
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
      {:atomic, :ok} ->
        :ok

      {:aborted, {:already_exists, :auth_challenges}} ->
        :ok

      {:aborted, reason} ->
        require Logger
        Logger.error("Failed to initialize Mnesia table: #{inspect(reason)}")
        {:error, reason}
    end
  end
end
