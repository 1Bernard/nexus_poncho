defmodule Nexus.Schema do
  @moduledoc """
  The Industrial Blueprint for all Nexus Data.

  Every domain (Identity, Treasury, ERP) uses this to ensure:
  1. UUIDv7: For time-ordered primary keys (better for DB performance).
  2. Microsecond Timestamps: Essential for financial audit precision.
  """
  defmacro __using__(_) do
    quote do
      use Ecto.Schema
      import Ecto.Changeset

      # UUIDv7 is the industry standard for scalable, ordered IDs
      @primary_key {:id, :binary_id, autogenerate: false}
      @foreign_key_type :binary_id
      @timestamps_opts [type: :utc_datetime_usec, inserted_at: :created_at]

      # Multi-tenancy: Every record belongs to an organization.
      # We handle this by explicitly requiring `field :org_id, :binary_id`
      # in every projection schema block (e.g., identity/projections/user.ex).
    end
  end

  @spec generate_uuidv7() :: String.t()
  def generate_uuidv7, do: Uniq.UUID.uuid7()

  @doc """
  Returns the current DateTime truncated to microseconds.
  Essential for financial audit precision.
  """
  @spec utc_now() :: DateTime.t()
  def utc_now, do: DateTime.utc_now() |> DateTime.truncate(:microsecond)

  @doc """
  Safely parses a datetime from a binary or returns the DateTime if already parsed.
  Returns `utc_now()` if input is nil or invalid.
  """
  @spec parse_datetime(DateTime.t() | String.t() | nil) :: DateTime.t()
  def parse_datetime(%DateTime{} = dt), do: dt |> DateTime.truncate(:microsecond)

  def parse_datetime(iso8601) when is_binary(iso8601) do
    case DateTime.from_iso8601(iso8601) do
      {:ok, dt, _offset} -> dt |> DateTime.truncate(:microsecond)
      {:error, _reason} -> utc_now()
    end
  end

  def parse_datetime(_), do: utc_now()

  @doc """
  Centralized decimal parsing for financial precision.
  Handles Decimal structs, strings, and numbers.
  """
  @spec parse_decimal(Decimal.t() | String.t() | number() | nil) :: Decimal.t()
  def parse_decimal(val) when is_struct(val, Decimal), do: val
  def parse_decimal(val) when is_binary(val), do: Decimal.new(String.trim(val))
  def parse_decimal(val) when is_number(val), do: Decimal.from_float(val * 1.0)
  def parse_decimal(nil), do: Decimal.new("0")

  @doc """
  Safely parses a decimal by stripping non-numeric characters (except . and -).
  Returns 0 if input is nil or invalid.
  """
  @spec parse_decimal_safe(Decimal.t() | String.t() | number() | nil) :: Decimal.t()
  def parse_decimal_safe(nil), do: Decimal.new("0")

  def parse_decimal_safe(val) when is_binary(val) do
    normalised = String.replace(val, ~r/[^0-9.-]/, "")

    case Decimal.parse(normalised) do
      {decimal, ""} -> decimal
      _ -> Decimal.new("0")
    end
  end

  def parse_decimal_safe(val), do: parse_decimal(val)
end
