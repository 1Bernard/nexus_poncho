defmodule Nexus do
  @moduledoc """
  Public API Gateway for the Soul layer.
  Provides a stable interface for the Face layer (nexus_web).
  """

  @doc """
  Dispatches a command to the core domain.
  """
  def dispatch(command, opts \\ []) do
    opts = Keyword.put_new(opts, :include_execution_result, true)
    Nexus.App.dispatch(command, opts)
  end

  @doc """
  Queries the read side.
  """
  def query(queryable, opts \\ []) do
    Nexus.Repo.all(queryable, opts)
  end
end
