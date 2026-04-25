defmodule Nexus.Router do
  @moduledoc """
  Commanded Router for the Nexus Soul layer.
  """
  use Commanded.Commands.Router

  middleware(Nexus.Shared.Middleware.OpenTelemetry)
  middleware(Nexus.Shared.Middleware.CorrelationId)
  middleware(Nexus.Shared.Middleware.Idempotency)
  middleware(Nexus.Shared.Middleware.TenantGate)

  @doc """
  Ensure all events carry the traceparent from the command metadata.
  """
  def event_metadata(%{metadata: metadata}) do
    Map.take(metadata, ["traceparent"])
  end

  alias Nexus.Accounting.Aggregates.Account
  alias Nexus.Accounting.Commands.OpenAccount

  alias Nexus.Treasury.Aggregates.Vault
  alias Nexus.Treasury.Commands.{CreditVault, RegisterVault}

  alias Nexus.Identity.Aggregates.{Session, User}

  alias Nexus.Identity.Commands.{
    ActivateUser,
    DeactivateUser,
    EnrollBiometric,
    ExpireSession,
    RegisterUser,
    StartSession,
    UpdateUserRole
  }

  alias Nexus.Compliance.Aggregates.Screening
  alias Nexus.Compliance.Commands.{CompletePEPCheck, PerformPEPCheck}

  alias Nexus.Marketing.Aggregates.AccessRequest, as: MarketingAccessRequest

  alias Nexus.Marketing.Commands.{
    ApproveAccessRequest,
    ArchiveAccessRequest,
    RejectAccessRequest,
    ReviewAccessRequest,
    SubmitAccessRequest
  }

  # ==================== ACCOUNTING ====================

  dispatch(OpenAccount,
    to: Account,
    identity: :account_id
  )

  # ==================== TREASURY ====================

  dispatch([RegisterVault, CreditVault],
    to: Vault,
    identity: :vault_id
  )

  # ==================== IDENTITY — User lifecycle ====================

  dispatch([RegisterUser, ActivateUser, EnrollBiometric, DeactivateUser, UpdateUserRole],
    to: User,
    identity: :user_id
  )

  # ==================== IDENTITY — Session lifecycle ====================

  dispatch([StartSession, ExpireSession],
    to: Session,
    identity: :session_id
  )

  # ==================== COMPLIANCE ====================

  dispatch([PerformPEPCheck, CompletePEPCheck],
    to: Screening,
    identity: :screening_id
  )

  # ==================== MARKETING — Access request lifecycle ====================

  dispatch(
    [
      SubmitAccessRequest,
      ReviewAccessRequest,
      ApproveAccessRequest,
      RejectAccessRequest,
      ArchiveAccessRequest
    ],
    to: MarketingAccessRequest,
    identity: :request_id
  )
end
