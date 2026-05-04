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

      lookup =
        try do
          find_idempotency_key(command, id_key)
        rescue
          # Sandbox processes (process manager GenServers) don't own a checked-out
          # connection. Fail-open so commands proceed — idempotency still works for
          # callers that hold a real connection (web, workers, :no_sandbox tests).
          DBConnection.ConnectionError -> nil
        end

      case lookup do
        nil ->
          pipeline_with_key

        _found ->
          Logger.info(
            "[Idempotency] Duplicate command intercepted. Halting pipeline for key: #{id_key}"
          )

          pipeline_with_key
          |> Pipeline.respond(:ok)
          |> Pipeline.halt()
      end
    end
  end

  @spec after_dispatch(Pipeline.t()) :: Pipeline.t()
  def after_dispatch(%Pipeline{} = pipeline), do: pipeline

  @spec after_failure(Pipeline.t()) :: Pipeline.t()
  def after_failure(%Pipeline{} = pipeline), do: pipeline

  # Identity
  defp find_idempotency_key(%Nexus.Identity.Commands.RegisterUser{}, id) do
    Repo.get(Nexus.Identity.Projections.IdempotencyKey, id)
  end

  defp find_idempotency_key(%Nexus.Identity.Commands.ActivateUser{}, id) do
    Repo.get(Nexus.Identity.Projections.IdempotencyKey, id)
  end

  defp find_idempotency_key(%Nexus.Identity.Commands.EnrollBiometric{}, id) do
    Repo.get(Nexus.Identity.Projections.IdempotencyKey, id)
  end

  defp find_idempotency_key(%Nexus.Identity.Commands.DeactivateUser{}, id) do
    Repo.get(Nexus.Identity.Projections.IdempotencyKey, id)
  end

  defp find_idempotency_key(%Nexus.Identity.Commands.UpdateUserRole{}, id) do
    Repo.get(Nexus.Identity.Projections.IdempotencyKey, id)
  end

  defp find_idempotency_key(%Nexus.Identity.Commands.StartSession{}, id) do
    Repo.get(Nexus.Identity.Projections.IdempotencyKey, id)
  end

  defp find_idempotency_key(%Nexus.Identity.Commands.ExpireSession{}, id) do
    Repo.get(Nexus.Identity.Projections.IdempotencyKey, id)
  end

  # Organization
  defp find_idempotency_key(%Nexus.Organization.Commands.ProvisionTenant{}, id) do
    Repo.get(Nexus.Organization.Projections.IdempotencyKey, id)
  end

  # Compliance
  defp find_idempotency_key(%Nexus.Compliance.Commands.PerformPEPCheck{}, id) do
    Repo.get(Nexus.Compliance.Projections.IdempotencyKey, id)
  end

  defp find_idempotency_key(%Nexus.Compliance.Commands.CompletePEPCheck{}, id) do
    Repo.get(Nexus.Compliance.Projections.IdempotencyKey, id)
  end

  # Accounting
  defp find_idempotency_key(%Nexus.Accounting.Commands.OpenAccount{}, id) do
    Repo.get(Nexus.Accounting.Projections.IdempotencyKey, id)
  end

  # Treasury
  defp find_idempotency_key(%Nexus.Treasury.Commands.RegisterVault{}, id) do
    Repo.get(Nexus.Treasury.Projections.IdempotencyKey, id)
  end

  defp find_idempotency_key(%Nexus.Treasury.Commands.CreditVault{}, id) do
    Repo.get(Nexus.Treasury.Projections.IdempotencyKey, id)
  end

  # Marketing
  defp find_idempotency_key(%Nexus.Marketing.Commands.SubmitAccessRequest{}, id) do
    Repo.get(Nexus.Marketing.Projections.IdempotencyKey, id)
  end

  defp find_idempotency_key(%Nexus.Marketing.Commands.ReviewAccessRequest{}, id) do
    Repo.get(Nexus.Marketing.Projections.IdempotencyKey, id)
  end

  defp find_idempotency_key(%Nexus.Marketing.Commands.ApproveAccessRequest{}, id) do
    Repo.get(Nexus.Marketing.Projections.IdempotencyKey, id)
  end

  defp find_idempotency_key(%Nexus.Marketing.Commands.RejectAccessRequest{}, id) do
    Repo.get(Nexus.Marketing.Projections.IdempotencyKey, id)
  end

  defp find_idempotency_key(%Nexus.Marketing.Commands.ArchiveAccessRequest{}, id) do
    Repo.get(Nexus.Marketing.Projections.IdempotencyKey, id)
  end

  # Fallback
  defp find_idempotency_key(_, _), do: nil
end
