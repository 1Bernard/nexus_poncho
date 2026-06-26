defmodule NexusWeb.Compliance.ExportController do
  @moduledoc """
  Serves bulk exports of the compliance screening ledger as CSV or Excel (.xlsx).
  """
  use NexusWeb, :controller

  import Ecto.Query

  alias Nexus.Compliance.Projections.Screening
  alias Nexus.Repo

  plug :ensure_authenticated

  def export(conn, params) do
    format = Map.get(params, "format", "csv")
    filter_status = Map.get(params, "status", "all")
    search = Map.get(params, "search", "")

    screenings = fetch_screenings(filter_status, search)
    date = Date.to_string(Date.utc_today())

    case format do
      "xlsx" ->
        data = build_xlsx(screenings)
        filename = "compliance-screenings-#{date}.xlsx"

        send_download(conn, {:binary, data},
          filename: filename,
          content_type: "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
        )

      _ ->
        data = build_csv(screenings)
        filename = "compliance-screenings-#{date}.csv"
        send_download(conn, {:binary, data}, filename: filename, content_type: "text/csv")
    end
  end

  defp fetch_screenings(filter_status, search) do
    base = from(s in Screening, order_by: [asc: s.status, asc: s.name])

    filtered =
      if filter_status != "all" do
        from(s in base, where: s.status == ^filter_status)
      else
        base
      end

    if search != "" do
      pattern = "%#{search}%"
      from(s in filtered, where: ilike(s.name, ^pattern))
    else
      filtered
    end
    |> Repo.all()
  end

  @csv_headers [
    "Name",
    "Screening Profile ID",
    "User ID",
    "Organization ID",
    "Status",
    "Inserted At",
    "Updated At"
  ]

  defp build_csv(screenings) do
    rows = Enum.map(screenings, &screening_to_row/1)

    [@csv_headers | rows]
    |> Enum.map_join("\r\n", fn row ->
      Enum.map_join(row, ",", &csv_escape/1)
    end)
  end

  defp csv_escape(value) do
    str = to_string(value || "")

    if String.contains?(str, [",", "\"", "\n", "\r"]) do
      ~s("#{String.replace(str, "\"", "\"\"")}")
    else
      str
    end
  end

  defp build_xlsx(screenings) do
    rows = Enum.map(screenings, &screening_to_row/1)

    sheet = %Elixlsx.Sheet{name: "Compliance Screenings", rows: [@csv_headers | rows]}
    workbook = %Elixlsx.Workbook{sheets: [sheet]}

    {:ok, {_filename, data}} = Elixlsx.write_to_memory(workbook, "compliance_screenings.xlsx")
    data
  end

  defp screening_to_row(s) do
    [
      s.name,
      s.id,
      s.user_id,
      s.org_id,
      s.status,
      Calendar.strftime(s.inserted_at, "%Y-%m-%d %H:%M:%S"),
      Calendar.strftime(s.updated_at, "%Y-%m-%d %H:%M:%S")
    ]
  end

  defp ensure_authenticated(conn, _opts),
    do: NexusWeb.UserAuth.require_authenticated(conn, [])
end
