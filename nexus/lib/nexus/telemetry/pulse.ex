defmodule Nexus.Telemetry.Pulse do
  @moduledoc """
  Generates a heartbeat span to verify Jaeger connectivity.
  """
  require OpenTelemetry.Tracer, as: Tracer

  def beat do
    Tracer.with_span "nexus.pulse" do
      Tracer.set_attribute("node", node())
      Tracer.set_attribute("service", System.get_env("NODE_NAME", "unknown"))

      # Simulate a small piece of work
      :timer.sleep(10)

      IO.puts("💓 [#{node()}] Pulse span generated.")
    end
  end
end
