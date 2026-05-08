defmodule Nexus.Marketing.Aggregates.AccessRequest do
  @moduledoc """
  Access Request aggregate.
  Lifecycle: submitted → (sanctions_screening: pending → clean) → under_review → approved | rejected → archived.

  Cooling-off guard: ReviewAccessRequest is blocked while sanctions_screening is "pending".
  A "flagged" result also blocks review — a compliance officer must manually override via archive.
  """

  defstruct [:request_id, :status, :email, :name, :organization, :sanctions_screening]

  alias __MODULE__, as: AccessRequest

  alias Nexus.Marketing.Commands.{
    ApproveAccessRequest,
    ArchiveAccessRequest,
    CompleteSanctionsScreening,
    InitiateSanctionsScreening,
    RejectAccessRequest,
    ReviewAccessRequest,
    SubmitAccessRequest
  }

  alias Nexus.Marketing.Events.{
    AccessRequestApproved,
    AccessRequestArchived,
    AccessRequestRejected,
    AccessRequestReviewed,
    AccessRequestSubmitted,
    SanctionsScreeningCompleted,
    SanctionsScreeningInitiated
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

  def execute(%AccessRequest{status: "pending"}, %InitiateSanctionsScreening{} = cmd) do
    %SanctionsScreeningInitiated{
      request_id: cmd.request_id,
      email: cmd.email,
      name: cmd.name,
      organization: cmd.organization
    }
  end

  def execute(%AccessRequest{}, %InitiateSanctionsScreening{}) do
    {:error, :cannot_initiate_screening_in_current_state}
  end

  def execute(%AccessRequest{sanctions_screening: "pending"}, %CompleteSanctionsScreening{} = cmd) do
    %SanctionsScreeningCompleted{
      request_id: cmd.request_id,
      result: cmd.result,
      matched_list: cmd.matched_list
    }
  end

  def execute(%AccessRequest{}, %CompleteSanctionsScreening{}) do
    {:error, :screening_not_in_progress}
  end

  # Cooling-off guard: block review while screening is active or flagged.
  def execute(
        %AccessRequest{status: "pending", sanctions_screening: "pending"},
        %ReviewAccessRequest{}
      ) do
    {:error, :sanctions_screening_in_progress}
  end

  def execute(
        %AccessRequest{status: "pending", sanctions_screening: "flagged"},
        %ReviewAccessRequest{}
      ) do
    {:error, :sanctions_screening_flagged}
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
        name: event.name,
        organization: event.organization
    }
  end

  def apply(%AccessRequest{} = state, %SanctionsScreeningInitiated{}) do
    %AccessRequest{state | sanctions_screening: "pending"}
  end

  def apply(%AccessRequest{} = state, %SanctionsScreeningCompleted{result: result}) do
    %AccessRequest{state | sanctions_screening: result}
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
