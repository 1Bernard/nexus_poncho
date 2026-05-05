defmodule Nexus.Organization.Idempotency.IdempotencyKey do
  @moduledoc """
  Read model for Organization idempotency tracking.
  Follows Standard Chapter 8: Idempotency.
  """
  use Nexus.Schema

  schema "organization_idempotency_keys" do
    field(:command_name, :string)
    field(:execution_result, :map)
    field(:executed_at, :utc_datetime_usec)

    timestamps(type: :utc_datetime_usec, inserted_at: :created_at)
  end

  def changeset(idempotency_key, attrs) do
    idempotency_key
    |> cast(attrs, [:id, :command_name, :execution_result, :executed_at])
    |> validate_required([:id, :command_name, :executed_at])
  end
end
