defmodule Nexus.Organization.Projections.AuditLog do
  @moduledoc """
  Read model for Organization business audits.
  Follows Standard Chapter 18: The Audit Log.
  """
  use Nexus.Schema

  schema "organization_audit_logs" do
    field(:event_id, :binary_id)
    field(:org_id, :binary_id)
    field(:event_type, :string)
    field(:payload, :map)
    field(:recorded_at, :utc_datetime_usec)
    field(:signature, :string)

    timestamps(type: :utc_datetime_usec, inserted_at: :created_at)
  end

  def changeset(audit_log, attrs) do
    audit_log
    |> cast(attrs, [:id, :event_id, :org_id, :event_type, :payload, :recorded_at, :signature])
    |> validate_required([:event_id, :org_id, :event_type, :payload, :recorded_at])
  end
end
