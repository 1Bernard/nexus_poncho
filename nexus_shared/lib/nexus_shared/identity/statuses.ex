defmodule NexusShared.Identity.Statuses do
  @moduledoc """
  Canonical status definitions for the Identity domain.

  User and Session statuses are defined here once and imported by both
  nexus (Soul) and nexus_web (Face). Never use bare status strings — always
  reference the functions below so that a status rename is a single-file change.
  """

  # ── User Statuses ────────────────────────────────────────────────────────────

  @doc "Registered but biometric not yet enrolled."
  def invited, do: "invited"

  @doc "Biometric enrolled; awaiting compliance (PEP) clearance."
  def registered, do: "registered"

  @doc "Fully verified. All treasury operations permitted."
  def active, do: "active"

  @doc "Offboarded, suspended, or compliance-revoked. No access."
  def deactivated, do: "deactivated"

  def user_statuses, do: [invited(), registered(), active(), deactivated()]

  @doc "Returns true if the given string is a recognised user status."
  def valid_user_status?(s) when is_binary(s), do: s in user_statuses()
  def valid_user_status?(_), do: false

  # ── Session Statuses ─────────────────────────────────────────────────────────

  @doc "Biometric session is active and within its TTL."
  def session_active, do: "active"

  @doc "Session was explicitly expired (logout / revocation) or TTL elapsed."
  def session_expired, do: "expired"

  def session_statuses, do: [session_active(), session_expired()]
end
