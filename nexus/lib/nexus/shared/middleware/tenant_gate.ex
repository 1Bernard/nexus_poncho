defmodule Nexus.Shared.Middleware.TenantGate do
  @moduledoc """
  Commanded Middleware that enforces Multi-Tenancy (Hardware V2 Isolation).

  Intercepts every command dispatched through the Nexus application router.
  Ensures that the `org_id` context is present. Halts the pipeline if missing,
  except for the genesis command `ProvisionOrganization` which bootstraps
  the tenant itself.
  """
  @behaviour Commanded.Middleware

  alias Commanded.Middleware.Pipeline

  # We allow system/genesis commands to bypass the gate.
  @spec before_dispatch(Pipeline.t()) :: Pipeline.t()
  def before_dispatch(%Pipeline{command: cmd} = pipeline)
      when is_struct(cmd, Nexus.Organization.Commands.ProvisionTenant) or
             is_struct(cmd, Nexus.Treasury.Commands.RecordMarketTick) do
    pipeline
  end

  def before_dispatch(%Pipeline{command: command} = pipeline) do
    cond do
      # Marketing is a pre-tenant bootstrap pipeline — access requests exist before
      # any org is provisioned, so tenant context does not apply to this domain.
      marketing_command?(command) ->
        pipeline

      Map.has_key?(command, :org_id) and is_binary(Map.get(command, :org_id)) ->
        pipeline

      true ->
        pipeline
        |> Pipeline.respond({:error, :missing_tenant_context})
        |> Pipeline.halt()
    end
  end

  defp marketing_command?(cmd) do
    cmd.__struct__ |> Module.split() |> Enum.take(3) == ~w(Nexus Marketing Commands)
  end

  @spec after_dispatch(Pipeline.t()) :: Pipeline.t()
  def after_dispatch(pipeline), do: pipeline

  @spec after_failure(Pipeline.t()) :: Pipeline.t()
  def after_failure(pipeline), do: pipeline
end
