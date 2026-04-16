defmodule NexusShared.Identity.Types do
  @moduledoc """
  Shared Types for the Identity Domain.
  Ensures binary-compatibility between Core and Web nodes.
  """
  use TypedStruct

  typedstruct module: BinaryID, enforce: true do
    @typedoc "A unique binary identifier (UUID v4 or v7)"
    field :id, String.t()
  end

  typedstruct module: OrgID, enforce: true do
    @typedoc "Company or Subsidiary identifier"
    field :id, String.t()
  end

  @type role :: String.t()
  @type status :: String.t()

  @doc "Helper to generate a new BinaryID"
  def new_id do
    %BinaryID{id: Uniq.UUID.uuid7()}
  end
end
