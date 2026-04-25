defmodule Nexus.Marketing.ProcessManagers.AccessRequestProcessManager do
  @moduledoc """
  Access Request Process Manager.
  Orchestrates user provisioning once an institutional access request is approved.

  ## Flow

    AccessRequestApproved → RegisterUser (Identity domain)

  The process manager is the single authority for triggering identity provisioning
  in response to an approval decision. This keeps the admin UI free of cross-domain
  command dispatch and ensures provisioning is retried automatically on failure.

  ## Idempotency

  `provisioned_user_id` from the event is used as the idempotency key for
  `RegisterUser`, so event store replays and RabbitMQ redeliveries are safe —
  the Identity middleware will return the cached result on any duplicate dispatch.
  """
  use Commanded.ProcessManagers.ProcessManager,
    application: Nexus.App,
    name: __MODULE__

  alias Nexus.App
  alias Nexus.Identity.Commands.RegisterUser
  alias Nexus.Marketing.Events.AccessRequestApproved
  alias Nexus.Shared.Tracing

  require Logger
  require OpenTelemetry.Tracer

  @derive Jason.Encoder
  defstruct [:request_id]

  # ── Process Routing ──────────────────────────────────────────────────────

  def interested?(%AccessRequestApproved{request_id: id}), do: {:start, id}
  def interested?(_event), do: false

  # ── Command Dispatch ─────────────────────────────────────────────────────

  def handle(%__MODULE__{}, %AccessRequestApproved{} = event, metadata) do
    Tracing.extract_and_set_context(metadata)

    OpenTelemetry.Tracer.with_span "AccessRequestPM.ProvisionUser" do
      Logger.info(
        "[AccessRequestPM] Provisioning user #{event.provisioned_user_id} for #{event.email}"
      )

      tracing_metadata = Tracing.inject_context(%{})

      App.dispatch(
        %RegisterUser{
          user_id: event.provisioned_user_id,
          org_id: event.provisioned_org_id,
          email: event.email,
          name: event.name,
          role: event.role,
          credential_id: nil,
          cose_key: nil
        },
        metadata: Map.put(tracing_metadata, "idempotency_key", event.provisioned_user_id)
      )
    end
  end

  # ── State Mutators ───────────────────────────────────────────────────────

  def apply(%__MODULE__{} = state, %AccessRequestApproved{} = event) do
    %__MODULE__{state | request_id: event.request_id}
  end
end
