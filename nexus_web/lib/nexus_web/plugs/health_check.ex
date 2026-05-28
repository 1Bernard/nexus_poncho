defmodule NexusWeb.Plugs.HealthCheck do
  @moduledoc false
  @behaviour Plug

  import Plug.Conn

  # Short-circuits GET /health before Plug.Telemetry so health check polling
  # (HAProxy every 2s) never enters the Phoenix instrumentation pipeline.
  # Without this, health checks account for >99% of Phoenix HTTP metrics and
  # render request rate, latency, and error rate panels meaningless.
  def init(opts), do: opts

  def call(%Plug.Conn{request_path: "/health", method: "GET"} = conn, _opts) do
    conn
    |> put_resp_content_type("text/plain")
    |> send_resp(200, "ok")
    |> halt()
  end

  def call(conn, _opts), do: conn
end
