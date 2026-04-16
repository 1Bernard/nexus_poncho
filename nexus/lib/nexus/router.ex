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
  alias Nexus.Treasury.Commands.{RegisterVault, CreditVault}

  alias Nexus.Identity.Aggregates.User
  alias Nexus.Identity.Commands.{RegisterUser, ActivateUser, EnrollBiometric}

  alias Nexus.Compliance.Aggregates.Screening
  alias Nexus.Compliance.Commands.{PerformPEPCheck, CompletePEPCheck}

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

  # ==================== IDENTITY ====================

  dispatch([RegisterUser, ActivateUser, EnrollBiometric],
    to: User,
    identity: :user_id
  )

  # ==================== COMPLIANCE ====================

  dispatch([PerformPEPCheck, CompletePEPCheck],
    to: Screening,
    identity: :screening_id
  )
end
