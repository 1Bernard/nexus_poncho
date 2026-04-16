defmodule Nexus.PromEx do
  @moduledoc """
  PromEx configuration for the Nexus core application.
  Exposes BEAM, Ecto, and Application metrics.
  """
  use PromEx, otp_app: :nexus

  alias PromEx.Plugins

  @impl true
  def plugins do
    [
      # PromEx built in plugins
      Plugins.Application,
      Plugins.Beam,
      {Plugins.Ecto, repos: [Nexus.Repo]}
    ]
  end

  @impl true
  def dashboard_assigns do
    [
      datasource_id: "prometheus",
      default_selected_interval: "30s",
      job_name: "nexus"
    ]
  end

  @impl true
  def dashboards do
    [
      # PromEx built in Grafana dashboards
      {:prom_ex, "application.json"},
      {:prom_ex, "beam.json"},
      {:prom_ex, "ecto.json"}
    ]
  end
end
