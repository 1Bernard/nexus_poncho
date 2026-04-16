defmodule NexusWeb.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    # Elite Precision: Ensure the observability stack is live before any bridge setups.
    {:ok, _} = Application.ensure_all_started(:opentelemetry)

    if Code.ensure_loaded?(OpentelemetryPhoenix) do
      OpentelemetryPhoenix.setup()
    end

    if Code.ensure_loaded?(OpentelemetryLiveView) do
      OpentelemetryLiveView.setup()
    end

    # Standalone Gateway mode: web is an isolated command dispatcher — no Erlang cluster.
    # Cluster.Supervisor is excluded entirely; it has no peers to connect to.
    # Worker mode (node1, node2): full Epmd-based cluster via Nexus.Application.
    cluster_children =
      if System.get_env("STANDALONE_GATEWAY") == "true" do
        []
      else
        topologies = Application.get_env(:libcluster, :topologies, [])
        [{Cluster.Supervisor, [topologies, [name: NexusWeb.ClusterSupervisor]]}]
      end

    children =
      cluster_children ++
        [
          NexusWeb.PromEx,
          NexusWeb.Telemetry,
          {Phoenix.PubSub, name: NexusWeb.PubSub},
          NexusWeb.Endpoint
        ]

    # LokiLogger is started by Nexus.Application (a dependency of nexus_web).
    # It registers a global OTP logger handler that captures logs from all apps
    # including nexus_web — no second instance needed here.

    opts = [strategy: :one_for_one, name: NexusWeb.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    NexusWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
