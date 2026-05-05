defmodule Nexus.Treasury.Projections.IdempotencyKey do
  @moduledoc """
  Ecto Schema for tracking Treasury Idempotency.
  Ensures financial commands are processed only once.
  """
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: false}
  @foreign_key_type :binary_id

  schema "treasury_idempotency_keys" do
    field(:command_name, :string)
    field(:executed_at, :utc_datetime_usec)

    timestamps(type: :utc_datetime_usec, inserted_at: :created_at)
  end

  def changeset(key, attrs) do
    key
    |> cast(attrs, [:id, :command_name, :executed_at])
    |> validate_required([:id, :command_name, :executed_at])
    |> unique_constraint(:id)
  end
end
