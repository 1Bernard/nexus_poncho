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
      {Plugins.Application,
       git_sha_mfa: {__MODULE__, :git_sha, []}, git_author_mfa: {__MODULE__, :git_author, []}},
      Plugins.Beam,
      {Plugins.Ecto, repos: [Nexus.Repo]}
    ]
  end

  def git_sha do
    case System.cmd("git", ["log", "-1", "--format=%H"], stderr_to_stdout: true, cd: "/app") do
      {sha, 0} -> String.trim(sha)
      _ -> System.get_env("GIT_SHA", "unavailable")
    end
  end

  def git_author do
    case System.cmd("git", ["log", "-1", "--format=%aN"], stderr_to_stdout: true, cd: "/app") do
      {author, 0} -> String.trim(author)
      _ -> System.get_env("GIT_AUTHOR", "unavailable")
    end
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
