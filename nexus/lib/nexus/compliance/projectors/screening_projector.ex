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
  alias Nexus.Compliance.Projections.Screening

  project(%PEPCheckInitiated{} = event, metadata, fn multi ->
    multi
    |> Multi.run(:insert_screening, fn repo, _ ->
      require OpenTelemetry.Tracer
      Nexus.Shared.Tracing.extract_and_set_context(metadata)

      OpenTelemetry.Tracer.with_span "Projector.Compliance.PEPCheckInitiated" do
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
      end
    end)
  end)

  project(%PEPCheckCompleted{} = event, metadata, fn multi ->
    multi
    |> Multi.run(:update_screening, fn repo, _ ->
      require OpenTelemetry.Tracer
      Nexus.Shared.Tracing.extract_and_set_context(metadata)

      OpenTelemetry.Tracer.with_span "Projector.Compliance.PEPCheckCompleted" do
        {count, _} =
          repo.update_all(
            from(s in Screening, where: s.id == ^event.screening_id),
            set: [status: event.status]
          )

        {:ok, count}
      end
    end)
  end)
end
