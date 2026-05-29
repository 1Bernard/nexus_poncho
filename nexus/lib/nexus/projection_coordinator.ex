defmodule Nexus.ProjectionCoordinator do
  @moduledoc """
  Starts every domain projector, event handler, and process manager as a
  globally-unique Horde-managed process.

  ## Global uniqueness mechanism

  Horde.DynamicSupervisor distributes processes across nodes but does NOT
  deduplicate by module name on its own. Deduplication requires a paired
  Horde.Registry entry. This coordinator uses a two-step claim:

    1. `Horde.Registry.register/3` — tries to claim the module as a key in
       the distributed registry. Only ONE node across the cluster wins.
    2. `Horde.DynamicSupervisor.start_child/2` — starts the process under
       the Horde supervisor, which migrates it on node failure.

  The registry entry is held by the coordinator process on whichever node
  wins the claim. If that node dies, the registry entry disappears, allowing
  a node that detects the loss to reclaim it and restart the projector.

  ## Adding a new projector

  Add the module to @projectors. No docker-compose edits needed.

  ## EmailWorker is intentionally excluded

  Nexus.Messaging.Workers.EmailWorker (Broadway/RabbitMQ consumer) runs as a
  direct supervisor child on every worker node. Multiple instances are
  desirable — each pulls from the queue independently, increasing throughput.
  """

  use GenServer
  require Logger

  @projectors [
    # Identity
    Nexus.Identity.Projectors.UserProjector,
    Nexus.Identity.Projectors.SessionProjector,
    Nexus.Identity.Projectors.AuditLogProjector,
    # Organisation
    Nexus.Organization.Projectors.TenantProjector,
    # Compliance
    Nexus.Compliance.Projectors.ScreeningProjector,
    Nexus.Compliance.Handlers.PEPHandler,
    Nexus.Compliance.Handlers.SanctionsHandler,
    Nexus.Compliance.Projectors.AuditLogProjector,
    # Accounting
    Nexus.Accounting.Projectors.AccountProjector,
    # Treasury
    Nexus.Treasury.Projectors.VaultProjector,
    # Messaging
    Nexus.Messaging.Handlers.EmailHandler,
    # Onboarding
    Nexus.Onboarding.ProcessManagers.OnboardingProcessManager,
    Nexus.Onboarding.Projectors.EntityKybProjector,
    # Platform audit
    Nexus.Audit.Projectors.PlatformAuditProjector,
    # Marketing
    Nexus.Marketing.Projectors.AccessRequestProjector,
    Nexus.Marketing.Projectors.AuditLogProjector,
    Nexus.Marketing.ProcessManagers.AccessRequestProcessManager
  ]

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(_opts) do
    # Allow HordeCluster to finish syncing membership before claiming projectors.
    # Without the delay, a node that boots while the cluster is forming would claim
    # all projectors locally — then when the other node joins, there would be no
    # projectors left to distribute, defeating the purpose of having two nodes.
    Process.send_after(self(), :start_projectors, 2_000)
    {:ok, %{pending: []}}
  end

  @impl true
  def handle_info(:start_projectors, state) do
    pending = Enum.reject(@projectors, &claim_and_start/1)

    if pending != [] do
      Logger.warning(
        "[ProjectionCoordinator] #{length(pending)} projector(s) pending retry: #{inspect(pending)}"
      )

      Process.send_after(self(), :retry_pending, 5_000)
    else
      Logger.info(
        "[ProjectionCoordinator] All #{length(@projectors)} projectors running across cluster"
      )
    end

    {:noreply, %{state | pending: pending}}
  end

  @impl true
  def handle_info(:retry_pending, %{pending: []} = state), do: {:noreply, state}

  @impl true
  def handle_info(:retry_pending, %{pending: pending} = state) do
    Logger.info("[ProjectionCoordinator] Retrying #{length(pending)} pending projector(s)")
    still_pending = Enum.reject(pending, &claim_and_start/1)

    if still_pending != [] do
      Process.send_after(self(), :retry_pending, 5_000)
    else
      Logger.info(
        "[ProjectionCoordinator] All #{length(@projectors)} projectors running across cluster"
      )
    end

    {:noreply, %{state | pending: still_pending}}
  end

  # Tries to claim a global registry slot for this projector, then starts it
  # under HordeSupervisor. Returns true when the projector is running (either
  # claimed by this node or already claimed by another). Returns false on
  # transient errors so the caller can schedule a retry.
  defp claim_and_start(module) do
    case Horde.Registry.register(Nexus.HordeRegistry, module, :coordinator) do
      {:ok, _pid} ->
        # This node won the global claim. Start the projector under HordeSupervisor
        # so it gets automatically migrated if this node dies.
        start_under_horde(module)

      {:error, {:already_registered, _pid}} ->
        # Another node in the cluster already holds this projector. Nothing to do.
        Logger.debug("[ProjectionCoordinator] #{inspect(module)} already claimed in cluster")
        true
    end
  end

  defp start_under_horde(module) do
    child_spec = Supervisor.child_spec(module, [])

    case Horde.DynamicSupervisor.start_child(Nexus.HordeSupervisor, child_spec) do
      {:ok, _pid} ->
        Logger.info("[ProjectionCoordinator] Started #{inspect(module)}")
        true

      {:error, {:already_started, _pid}} ->
        Logger.debug("[ProjectionCoordinator] #{inspect(module)} already running in cluster")
        true

      {:error, :not_found} ->
        Logger.warning(
          "[ProjectionCoordinator] HordeSupervisor not ready for #{inspect(module)}, will retry"
        )

        false

      {:error, reason} ->
        Logger.error(
          "[ProjectionCoordinator] Failed to start #{inspect(module)}: #{inspect(reason)}"
        )

        false
    end
  end
end
