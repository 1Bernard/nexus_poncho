defmodule Nexus.Organization.Aggregates.Tenant do
  @moduledoc """
  Tenant aggregate. Owns the organization provisioning lifecycle.
  ProvisionTenant is the only entry point — a tenant cannot be created twice.
  """

  defstruct [:org_id, :name, :status]

  alias __MODULE__, as: Tenant
  alias Nexus.Organization.Commands.ProvisionTenant
  alias Nexus.Organization.Events.TenantProvisioned

  require Logger

  @tenant_active "active"

  # ── Command Handlers ──────────────────────────────────────────────────────

  def execute(%Tenant{org_id: nil}, %ProvisionTenant{} = cmd) do
    %TenantProvisioned{
      org_id: cmd.org_id,
      name: cmd.name,
      initial_admin_email: cmd.initial_admin_email,
      provisioned_by: cmd.provisioned_by,
      provisioned_at: cmd.provisioned_at
    }
  end

  def execute(%Tenant{}, %ProvisionTenant{}) do
    {:error, :tenant_already_exists}
  end

  def execute(%Tenant{} = state, command) do
    Logger.warning(
      "[TenantAggregate] Unhandled command #{inspect(command.__struct__)} in status #{inspect(state.status)}"
    )

    {:error, :invalid_command_for_current_state}
  end

  # ── State Transitions ─────────────────────────────────────────────────────

  def apply(%Tenant{} = state, %TenantProvisioned{} = event) do
    %Tenant{state | org_id: event.org_id, name: event.name, status: @tenant_active}
  end

  def apply(%Tenant{} = state, _event), do: state
end
