defmodule Nexus.Shared.Middleware.Idempotency do
  @moduledoc """
  Idempotency Middleware for the Nexus Platform.
  Intercepts commands and returns cached execution results if repeated.
  Follows Standard: Sovereign Determinism.
  """
  @behaviour Commanded.Middleware
  alias Commanded.Middleware.Pipeline
  alias Nexus.Repo

  require Logger

  @spec before_dispatch(Pipeline.t()) :: Pipeline.t()
  def before_dispatch(%Pipeline{command: command} = pipeline) do
    # Extract idempotency key from metadata or causation_id
    metadata = pipeline.metadata || %{}

    id_key =
      Map.get(metadata, "idempotency_key") || Map.get(metadata, :idempotency_key) ||
        pipeline.causation_id

    if is_nil(id_key) do
      pipeline
    else
      # Assign the derived idempotency key so projectors can use it reliably without guessing
      updated_metadata = Map.put(metadata, "idempotency_key", id_key)
      pipeline_with_key = %{pipeline | metadata: updated_metadata}

      case find_idempotency_key(command, id_key) do
        nil ->
          pipeline_with_key

        %{execution_result: result} ->
          Logger.info(
            "[Idempotency] Duplicate command intercepted. Returning cached result for key: #{id_key}"
          )

          pipeline_with_key
          |> Pipeline.respond({:ok, result})
          |> Pipeline.halt()
      end
    end
  end

  @spec after_dispatch(Pipeline.t()) :: Pipeline.t()
  def after_dispatch(%Pipeline{} = pipeline), do: pipeline

  @spec after_failure(Pipeline.t()) :: Pipeline.t()
  def after_failure(%Pipeline{} = pipeline), do: pipeline

  # Domain specific mapping to Idempotency tables
  defp find_idempotency_key(%Nexus.Identity.Commands.RegisterUser{}, id) do
    Repo.get(Nexus.Identity.Idempotency.IdempotencyKey, id)
  end

  defp find_idempotency_key(%Nexus.Identity.Commands.EnrollBiometric{}, id) do
    Repo.get(Nexus.Identity.Idempotency.IdempotencyKey, id)
  end

  defp find_idempotency_key(%Nexus.Identity.Commands.DeactivateUser{}, id) do
    Repo.get(Nexus.Identity.Idempotency.IdempotencyKey, id)
  end

  defp find_idempotency_key(%Nexus.Identity.Commands.UpdateUserRole{}, id) do
    Repo.get(Nexus.Identity.Idempotency.IdempotencyKey, id)
  end

  defp find_idempotency_key(%Nexus.Identity.Commands.StartSession{}, id) do
    Repo.get(Nexus.Identity.Idempotency.IdempotencyKey, id)
  end

  defp find_idempotency_key(%Nexus.Accounting.Commands.OpenAccount{}, id) do
    Repo.get(Nexus.Accounting.Idempotency.IdempotencyKey, id)
  end

  # Fallback
  defp find_idempotency_key(_, _), do: nil
end
