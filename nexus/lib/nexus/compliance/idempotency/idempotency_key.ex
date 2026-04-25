defmodule Nexus.Compliance.Idempotency.IdempotencyKey do
  @moduledoc "Idempotency record for Compliance domain commands."

  use Nexus.Schema

  schema "compliance_idempotency_keys" do
    field(:command_name, :string)
    field(:executed_at, :utc_datetime_usec)

    timestamps(type: :utc_datetime_usec, inserted_at: :created_at)
  end

  def changeset(key, attrs) do
    key
    |> cast(attrs, [:id, :command_name, :executed_at])
    |> validate_required([:id, :command_name, :executed_at])
  end
end
