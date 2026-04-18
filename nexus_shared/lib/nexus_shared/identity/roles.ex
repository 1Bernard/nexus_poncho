defmodule NexusShared.Identity.Roles do
  @moduledoc """
  Canonical role definitions for the Identity domain.

  Both the Soul (nexus) and Face (nexus_web) reference these constants so that
  role values never drift between the two apps. Add new roles here — never as
  bare strings scattered across the codebase.
  """

  @admin "admin"
  @treasurer "treasurer"
  @viewer "viewer"
  @auditor "auditor"

  def admin, do: @admin
  def treasurer, do: @treasurer
  def viewer, do: @viewer
  def auditor, do: @auditor

  @doc "All valid role strings."
  def all, do: [@admin, @treasurer, @viewer, @auditor]

  @doc "Returns true if the given string is a recognised role."
  def valid?(role) when is_binary(role), do: role in all()
  def valid?(_), do: false
end
