defmodule Nexus.Marketing.Aggregates.AccessRequest do
  @moduledoc """
  Access Request aggregate.
  Owns the lifecycle: submitted → under_review → approved | rejected → archived.
  Follows Standard: Deterministic Engine.
  """

  defstruct [:request_id, :status, :email, :name]

  alias __MODULE__, as: AccessRequest

  alias Nexus.Marketing.Commands.{
    ApproveAccessRequest,
    ArchiveAccessRequest,
    RejectAccessRequest,
    ReviewAccessRequest,
    SubmitAccessRequest
  }

  alias Nexus.Marketing.Events.{
    AccessRequestApproved,
    AccessRequestArchived,
    AccessRequestRejected,
    AccessRequestReviewed,
    AccessRequestSubmitted
  }

  require Logger

  # ── Command Handlers ──────────────────────────────────────────────────────

  def execute(%AccessRequest{request_id: nil}, %SubmitAccessRequest{} = cmd) do
    %AccessRequestSubmitted{
      request_id: cmd.request_id,
      email: cmd.email,
      name: cmd.name,
      organization: cmd.organization,
      job_title: cmd.job_title,
      treasury_volume: cmd.treasury_volume,
      subsidiaries: cmd.subsidiaries,
      message: cmd.message
    }
  end

  def execute(%AccessRequest{}, %SubmitAccessRequest{}) do
    {:error, :access_request_already_submitted}
  end

  def execute(%AccessRequest{status: "pending"}, %ReviewAccessRequest{} = cmd) do
    %AccessRequestReviewed{request_id: cmd.request_id, reviewed_by: cmd.reviewed_by}
  end

  def execute(%AccessRequest{status: "under_review"} = state, %ApproveAccessRequest{} = cmd) do
    %AccessRequestApproved{
      request_id: cmd.request_id,
      approved_by: cmd.approved_by,
      role: cmd.role,
      provisioned_user_id: cmd.provisioned_user_id,
      provisioned_org_id: cmd.provisioned_org_id,
      email: state.email,
      name: state.name
    }
  end

  def execute(%AccessRequest{status: "under_review"}, %RejectAccessRequest{} = cmd) do
    %AccessRequestRejected{
      request_id: cmd.request_id,
      rejected_by: cmd.rejected_by,
      reason: cmd.reason
    }
  end

  def execute(%AccessRequest{status: status}, %ArchiveAccessRequest{} = cmd)
      when status not in ["archived", nil] do
    %AccessRequestArchived{request_id: cmd.request_id, archived_by: cmd.archived_by}
  end

  def execute(%AccessRequest{} = state, command) do
    Logger.warning(
      "[AccessRequestAggregate] Unhandled #{inspect(command.__struct__)} in status #{inspect(state.status)}"
    )

    {:error, :invalid_command_for_current_state}
  end

  # ── State Transitions ─────────────────────────────────────────────────────

  def apply(%AccessRequest{} = state, %AccessRequestSubmitted{} = event) do
    %AccessRequest{
      state
      | request_id: event.request_id,
        status: "pending",
        email: event.email,
        name: event.name
    }
  end

  def apply(%AccessRequest{} = state, %AccessRequestReviewed{}) do
    %AccessRequest{state | status: "under_review"}
  end

  def apply(%AccessRequest{} = state, %AccessRequestApproved{}) do
    %AccessRequest{state | status: "approved"}
  end

  def apply(%AccessRequest{} = state, %AccessRequestRejected{}) do
    %AccessRequest{state | status: "rejected"}
  end

  def apply(%AccessRequest{} = state, %AccessRequestArchived{}) do
    %AccessRequest{state | status: "archived"}
  end
end
