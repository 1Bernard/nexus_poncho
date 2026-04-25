defmodule Nexus.Marketing.RequestAccessFeatureTest do
  use Cabbage.Feature, file: "marketing/request_access.feature"
  use Nexus.DataCase

  @moduletag :feature

  alias Nexus.Marketing.Projections.AccessRequest
  alias Nexus.Repo

  # ══════════════════════════════════════════════════════════════════════════════
  # GIVEN
  # ══════════════════════════════════════════════════════════════════════════════

  defgiven ~r/^a prospective client submits an access request with:$/,
           %{table: table},
           state do
    params = Map.put_new(parse_table(table), "id", Uniq.UUID.uuid7())
    changeset = AccessRequest.changeset(%AccessRequest{}, params)
    result = Repo.insert(changeset)
    {:ok, Map.merge(state, %{params: params, result: result, changeset: changeset})}
  end

  # ══════════════════════════════════════════════════════════════════════════════
  # THEN
  # ══════════════════════════════════════════════════════════════════════════════

  defthen ~r/^the access request is accepted$/, _captures, state do
    assert {:ok, _record} = state.result,
           "Expected request to be accepted but got: #{inspect(state.result)}"

    {:ok, state}
  end

  defthen ~r/^the access request is rejected$/, _captures, state do
    assert {:error, %Ecto.Changeset{}} = state.result,
           "Expected request to be rejected but got: #{inspect(state.result)}"

    {:ok, state}
  end

  defthen ~r/^the access request is persisted with status "(?<status>[^"]+)"$/,
          %{status: expected_status},
          state do
    assert {:ok, record} = state.result
    assert record.status == expected_status

    {:ok, state}
  end

  defthen ~r/^the access request has errors on the "(?<field>[^"]+)" field$/,
          %{field: field},
          state do
    assert {:error, changeset} = state.result
    field_atom = String.to_existing_atom(field)

    assert changeset.errors[field_atom],
           "Expected error on #{inspect(field_atom)} but errors were: #{inspect(changeset.errors)}"

    {:ok, state}
  end

  defthen ~r/^an access request exists for email "(?<email>[^"]+)"$/,
          %{email: email},
          state do
    assert Repo.get_by(AccessRequest, email: email),
           "Expected an access request for #{email} to exist in the database"

    {:ok, state}
  end

  defthen ~r/^no access request exists for email "(?<email>[^"]+)"$/,
          %{email: email},
          state do
    refute Repo.get_by(AccessRequest, email: email),
           "Expected no access request for #{email} but one was found"

    {:ok, state}
  end

  # ══════════════════════════════════════════════════════════════════════════════
  # Private
  # ══════════════════════════════════════════════════════════════════════════════

  defp parse_table(table) do
    Enum.reduce(table, %{}, fn %{field: field, value: value}, acc ->
      Map.put(acc, field, value)
    end)
  end
end
