defmodule Nexus.DataCase do
  @moduledoc """
  This module defines the setup for tests requiring
  access to the application's data layer.
  """
  use ExUnit.CaseTemplate

  alias Ecto.Adapters.SQL.Sandbox

  using do
    quote do
      alias Nexus.Repo
      import Ecto
      import Ecto.Changeset
      import Ecto.Query
      import Nexus.DataCase
    end
  end

  setup tags do
    Nexus.DataCase.setup_sandbox(tags)
    :ok
  end

  def setup_sandbox(tags) do
    if tags[:no_sandbox] do
      owner = Sandbox.start_owner!(Nexus.Repo, shared: false)
      allow_commanded_handlers(owner)

      on_exit(fn ->
        # 1. Drain projectors — wait until all projectors are truly idle.
        drain_projectors(50)

        # 2. Re-allow projectors to a short-lived cleanup proxy BEFORE stopping
        # the test owner. This closes the race where an in-flight EventStore
        # notification (e.g. PEPCheckCompleted dispatched from PEPWorker)
        # arrives after the owner exits, causing the projector's checkout to
        # redirect to the now-dead proxy and hang indefinitely.
        cleanup = Sandbox.start_owner!(Nexus.Repo, shared: false)
        allow_commanded_handlers(cleanup)

        # 3. Stop the test owner — projectors now route through cleanup proxy.
        Sandbox.stop_owner(owner)

        # 4. Drain again to let any cascading EventStore events (e.g.
        # PEPCheckCompleted) complete via the cleanup proxy.
        drain_projectors(20)
        Sandbox.stop_owner(cleanup)
      end)
    else
      pid = Sandbox.start_owner!(Nexus.Repo, shared: not tags[:async])
      on_exit(fn -> Sandbox.stop_owner(pid) end)
    end
  end

  # App-managed projectors that must NOT be redirected to the test owner's
  # connection. They are supervised by the application (start_identity_projections:
  # true), process events asynchronously, and no test asserts on their writes.
  # Allowing them causes DBConnection.ConnectionError crashes when the test owner
  # exits while they are mid-transaction, which poisons subsequent tests.
  @excluded_handlers ~w[
    Identity.SessionProjector
    Identity.AuditLogProjector
  ]

  defp allow_commanded_handlers(owner) do
    registry = Nexus.App.LocalRegistry

    Registry.select(registry, [{{:"$1", :"$2", :"$3"}, [], [{{:"$1", :"$2", :"$3"}}]}])
    |> Enum.each(fn {{_app, _kind, handler_name}, pid, _} ->
      unless handler_name in @excluded_handlers do
        # unallow_existing: true forces the ETS entry to be replaced even if the
        # projector already has a stale :allowed entry pointing to a previous test's
        # (now-exited) owner proxy — without this, the short-circuit in
        # Manager.allow returns {:already, :allowed} and the entry is not updated.
        Sandbox.allow(Nexus.Repo, owner, pid, unallow_existing: true)
      end
    end)
  end

  # Wait for all registry processes to be idle, then do a double-check after a
  # short pause. The pause catches the race where a projector's queue appears
  # empty because PEPWorker just dispatched a command but the resulting EventStore
  # notification hasn't been delivered to the downstream projector yet.
  defp drain_projectors(0), do: :ok

  defp drain_projectors(attempts) do
    if all_projectors_idle?() do
      # Brief pause to let any in-flight EventStore → projector notifications land.
      Process.sleep(100)
      # Confirm still idle; if a notification arrived, loop back and wait again.
      unless all_projectors_idle?() do
        drain_projectors(attempts - 1)
      end
    else
      Process.sleep(50)
      drain_projectors(attempts - 1)
    end
  end

  defp all_projectors_idle? do
    Registry.select(Nexus.App.LocalRegistry, [
      {{:"$1", :"$2", :"$3"}, [], [{{:"$1", :"$2", :"$3"}}]}
    ])
    |> Enum.all?(fn {_key, pid, _} ->
      case Process.info(pid, [:message_queue_len, :current_function]) do
        [{:message_queue_len, 0}, {:current_function, {:gen_server, :loop, 5}}] -> true
        nil -> true
        _ -> false
      end
    end)
  end
end
