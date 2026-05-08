defmodule NexusShared.Identity.Roles do
  @moduledoc """
  Canonical role definitions for the Equinox platform.

  Roles split into two planes:
  - Platform roles: Equinox staff operations (super_admin, platform_support)
  - Org roles: Customer-facing treasury operations (group_treasurer, treasury_manager, etc.)

  Both the Soul (nexus) and Face (nexus_web) reference these constants so that
  role values never drift between the two apps.
  """

  # ── Platform Roles (Equinox internal staff) ───────────────────────────────
  # Stored on identity_users.platform_role — applies globally, not org-scoped.

  @super_admin "super_admin"
  @platform_support "platform_support"

  def super_admin, do: @super_admin
  def platform_support, do: @platform_support

  def all_platform, do: [@super_admin, @platform_support]
  def valid_platform?(role) when is_binary(role), do: role in all_platform()
  def valid_platform?(_), do: false

  # ── Org Roles (customer-facing treasury operations) ───────────────────────
  # Stored in user_roles join table — scoped to org_id / subsidiary_id.

  @group_treasurer "group_treasurer"
  @treasury_manager "treasury_manager"
  @treasury_analyst "treasury_analyst"
  @vault_manager "vault_manager"
  @compliance_officer "compliance_officer"
  @auditor "auditor"
  @org_admin "org_admin"

  # Legacy aliases kept for backward compatibility with existing provisioning flow
  @admin "admin"
  @treasurer "treasurer"
  @viewer "viewer"

  def group_treasurer, do: @group_treasurer
  def treasury_manager, do: @treasury_manager
  def treasury_analyst, do: @treasury_analyst
  def vault_manager, do: @vault_manager
  def compliance_officer, do: @compliance_officer
  def auditor, do: @auditor
  def org_admin, do: @org_admin

  # Legacy
  def admin, do: @admin
  def treasurer, do: @treasurer
  def viewer, do: @viewer

  def all_org do
    [
      @group_treasurer,
      @treasury_manager,
      @treasury_analyst,
      @vault_manager,
      @compliance_officer,
      @auditor,
      @org_admin,
      @admin,
      @treasurer,
      @viewer
    ]
  end

  @doc "All valid org role strings."
  def all, do: all_org()

  @doc "Returns true if the given string is a recognised org role."
  def valid?(role) when is_binary(role), do: role in all_org()
  def valid?(_), do: false

  @doc "Roles that can act as a maker (initiate operations)."
  def maker_roles, do: [@group_treasurer, @treasury_manager, @vault_manager, @admin, @treasurer]

  @doc "Roles that can act as a checker (approve operations)."
  def checker_roles, do: [@group_treasurer, @compliance_officer]
end
