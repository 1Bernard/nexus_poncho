defmodule Nexus.HordeCluster do
  @moduledoc """
  Manages the Horde distributed registry and dynamic supervisor for the Nexus cluster.

  This module is responsible for connecting the local Horde members to their
  counterparts on all other nodes in the `libcluster` mesh. It listens for
  `:nodeup` events and triggers a membership sync to ensure the distributed
  registry and supervisor are always aware of the full cluster topology.

  ## Architecture
  - `Nexus.HordeRegistry` — A distributed process registry. Replaces `Registry`
    for processes that must survive node failure.
  - `Nexus.HordeSupervisor` — A distributed dynamic supervisor. Processes started
    under it can be migrated to any living node automatically.
  """

  use GenServer

  require Logger

  @registry Nexus.HordeRegistry
  @supervisor Nexus.HordeSupervisor

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(_opts) do
    :net_kernel.monitor_nodes(true, node_type: :all)
    {:ok, %{}}
  end

  @impl true
  def handle_info({:nodeup, node, _info}, state) do
    Logger.info("[HordeCluster] Node joined: #{node}. Syncing Horde members.")
    sync_members()
    {:noreply, state}
  end

  @impl true
  def handle_info({:nodedown, node, _info}, state) do
    Logger.info("[HordeCluster] Node left: #{node}. Horde will self-heal.")
    {:noreply, state}
  end

  @impl true
  def handle_info(_msg, state), do: {:noreply, state}

  # Collect all live nodes (including self) and set the Horde member list.
  defp sync_members do
    all_nodes = [Node.self() | Node.list()]

    registry_members =
      Enum.map(all_nodes, fn node -> {@registry, node} end)

    supervisor_members =
      Enum.map(all_nodes, fn node -> {@supervisor, node} end)

    Horde.Cluster.set_members(@registry, registry_members)
    Horde.Cluster.set_members(@supervisor, supervisor_members)
  end
end
