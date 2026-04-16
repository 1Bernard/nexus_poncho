defmodule Nexus.Telemetry.Heartbeat do
  @moduledoc """
  A periodic GenServer that ensures idle distributed nodes stay visible in Jaeger.

  In a distributed telemetry stack, services that do not process active commands/events
  may disappear from the Jaeger "Service" list. This module emits a lightweight
  'heartbeat' span every 30 seconds to maintain a continuous telemetric presence,
  ensuring that the cluster topology is always accurately reflected in the UI.
  """
  use GenServer
  require OpenTelemetry.Tracer, as: Tracer

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(_opts) do
    # First one in 1s
    schedule_heartbeat(1000)
    {:ok, %{}}
  end

  @impl true
  def handle_info(:beat, state) do
    Tracer.with_span "nexus.heartbeat" do
      Tracer.set_attribute("node", node())
      Tracer.set_attribute("service", System.get_env("NODE_NAME", "unknown"))
    end

    # Every 30s
    schedule_heartbeat(30_000)
    {:noreply, state}
  end

  defp schedule_heartbeat(ms) do
    Process.send_after(self(), :beat, ms)
  end
end
