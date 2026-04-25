defmodule Nexus.Compliance.Projectors.ScreeningProjector do
  @moduledoc """
  Projector for PEP screenings.
  """
  use Commanded.Projections.Ecto,
    application: Nexus.App,
    name: "Compliance.ScreeningProjector",
    repo: Nexus.Repo

  import Ecto.Query
  alias Ecto.Multi
  alias Nexus.Compliance.Events.{PEPCheckCompleted, PEPCheckInitiated}
  alias Nexus.Compliance.Idempotency.IdempotencyKey
  alias Nexus.Compliance.Projections.Screening
  alias Nexus.Shared.Tracing

  project(%PEPCheckInitiated{} = event, metadata, fn multi ->
    require OpenTelemetry.Tracer
    Tracing.extract_and_set_context(metadata)

    OpenTelemetry.Tracer.with_span "Projector.Compliance.PEPCheckInitiated" do
      multi
      |> Multi.run(:insert_screening, fn repo, _ ->
        repo.insert(
          %Screening{
            id: event.screening_id,
            user_id: event.user_id,
            org_id: event.org_id,
            name: event.name,
            status: "pending"
          },
          on_conflict: :nothing,
          conflict_target: :id
        )
      end)
      |> track_idempotency(metadata, "PerformPEPCheck")
    end
  end)

  project(%PEPCheckCompleted{} = event, metadata, fn multi ->
    require OpenTelemetry.Tracer
    Tracing.extract_and_set_context(metadata)

    OpenTelemetry.Tracer.with_span "Projector.Compliance.PEPCheckCompleted" do
      multi
      |> Multi.run(:update_screening, fn repo, _ ->
        {count, _} =
          repo.update_all(
            from(s in Screening, where: s.id == ^event.screening_id),
            set: [status: event.status]
          )

        {:ok, count}
      end)
      |> track_idempotency(metadata, "CompletePEPCheck")
    end
  end)

  defp track_idempotency(multi, metadata, command_name) do
    attrs = %{
      id: metadata.causation_id || metadata.event_id,
      command_name: command_name,
      executed_at: Nexus.Schema.utc_now()
    }

    changeset = IdempotencyKey.changeset(%IdempotencyKey{}, attrs)

    Multi.insert(multi, :"idempotency_#{metadata.event_id}", changeset,
      on_conflict: :nothing,
      conflict_target: :id
    )
  end
end
