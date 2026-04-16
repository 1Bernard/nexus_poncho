defmodule Nexus.Compliance.Projections.Screening do
  @moduledoc """
  Read model for PEP screenings.
  """
  use Nexus.Schema

  schema "compliance_screenings" do
    field(:user_id, :binary_id)
    field(:org_id, :binary_id)
    field(:name, :string)
    # "pending", "clean", "flagged"
    field(:status, :string)

    timestamps()
  end

  def changeset(screening, attrs) do
    screening
    |> cast(attrs, [:id, :user_id, :org_id, :name, :status])
    |> validate_required([:id, :user_id, :org_id, :name, :status])
  end
end
