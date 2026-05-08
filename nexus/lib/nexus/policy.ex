defmodule Nexus.Policy do
  @moduledoc """
  Central Bodyguard policy for the Equinox platform.

  All authorization decisions flow through this module. LiveViews and controllers
  call Bodyguard.permit/4 with an action atom and a resource; this module pattern-
  matches to the correct RBAC check.

  ## Platform actions (Equinox staff only)
  These check identity_users.platform_role — no org scope required.

  ## Org actions (customer-facing)
  These check the user_roles join table with org/subsidiary scope.

  ## Usage

      with :ok <- Bodyguard.permit(Nexus.Policy, :review_access_request, user, request) do
        App.dispatch(...)
      end
  """

  @behaviour Bodyguard.Policy

  alias Nexus.RBAC

  # ── Access Request Management (platform staff) ───────────────────────────

  def authorize(:access_admin_panel, user, _),
    do: RBAC.platform_staff?(user)

  def authorize(:review_access_request, user, _),
    do: RBAC.has_platform_role?(user, [:super_admin, :platform_support])

  def authorize(:reject_access_request, user, _),
    do: RBAC.has_platform_role?(user, [:super_admin, :platform_support])

  def authorize(:archive_access_request, user, _),
    do: RBAC.has_platform_role?(user, [:super_admin, :platform_support])

  def authorize(:export_access_requests, user, _),
    do: RBAC.has_platform_role?(user, [:super_admin, :platform_support])

  # Approval is super_admin only — maker-checker enforced here
  def authorize(:approve_access_request, user, _),
    do: RBAC.super_admin?(user)

  # ── KYB & Compliance Review (platform staff) ─────────────────────────────

  def authorize(:review_kyb_submission, user, _),
    do: RBAC.has_platform_role?(user, [:super_admin, :platform_support])

  def authorize(:complete_risk_assessment, user, _),
    do: RBAC.super_admin?(user)

  # ── Organization Provisioning (super_admin only) ─────────────────────────

  def authorize(:provision_organization, user, _),
    do: RBAC.super_admin?(user)

  def authorize(:manage_platform_users, user, _),
    do: RBAC.super_admin?(user)

  # ── Treasury Operations (org-scoped) ─────────────────────────────────────

  def authorize(:initiate_transfer, user, %{subsidiary_id: sub_id}) do
    RBAC.has_role?(user, :treasury_manager, subsidiary_id: sub_id) or
      RBAC.has_role?(user, :group_treasurer, org_id: user.org_id) or
      RBAC.has_role?(user, :admin, org_id: user.org_id)
  end

  def authorize(:approve_operation, user, %{required_role: required}) do
    RBAC.has_role?(user, String.to_atom(required), org_id: user.org_id)
  end

  def authorize(:manage_vault, user, %{id: vault_id}) do
    RBAC.has_entity_permission?(user, :vault, vault_id, :manage) or
      RBAC.has_role?(user, :group_treasurer, org_id: user.org_id)
  end

  def authorize(:view_audit_trail, user, %{org_id: org_id}) do
    RBAC.has_role?(user, :auditor, org_id: org_id) or
      RBAC.has_role?(user, :compliance_officer, org_id: org_id) or
      RBAC.super_admin?(user)
  end

  # ── Org Administration ────────────────────────────────────────────────────

  def authorize(:manage_org_users, user, %{org_id: org_id}) do
    RBAC.has_role?(user, :org_admin, org_id: org_id) or
      RBAC.has_role?(user, :admin, org_id: org_id) or
      RBAC.super_admin?(user)
  end

  # ── Catch-all ─────────────────────────────────────────────────────────────

  def authorize(_, _, _), do: false
end
