defmodule NexusWeb.Admin.ExportController do
  @moduledoc """
  Serves bulk exports of the access request ledger as CSV or Excel (.xlsx).

  Downloads are handled by a controller — not a LiveView push_event — because
  file downloads are HTTP, not WebSocket. The controller reads the same filter
  and search params the admin LiveView uses, so the exported data always matches
  what the admin is currently viewing.

  Route: GET /admin/access-requests/export?format=csv|xlsx&status=...&search=...
  """
  use NexusWeb, :controller

  import Ecto.Query

  alias Nexus.Marketing.Projections.AccessRequest
  alias Nexus.Repo

  plug :ensure_authenticated

  # ── Action ───────────────────────────────────────────────────────────────────

  def export(conn, params) do
    format = Map.get(params, "format", "csv")
    filter_status = Map.get(params, "status", "all")
    search = Map.get(params, "search", "")

    requests = fetch_requests(filter_status, search)
    date = Date.to_string(Date.utc_today())

    case format do
      "xlsx" ->
        data = build_xlsx(requests)
        filename = "access-requests-#{date}.xlsx"

        send_download(conn, {:binary, data},
          filename: filename,
          content_type: "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
        )

      _ ->
        data = build_csv(requests)
        filename = "access-requests-#{date}.csv"
        send_download(conn, {:binary, data}, filename: filename, content_type: "text/csv")
    end
  end

  # ── Query ─────────────────────────────────────────────────────────────────────

  defp fetch_requests(filter_status, search) do
    base = from(r in AccessRequest, order_by: [desc: r.created_at])

    filtered =
      if filter_status != "all" do
        from(r in base, where: r.status == ^filter_status)
      else
        base
      end

    if search != "" do
      pattern = "%#{search}%"

      from(r in filtered,
        where:
          ilike(r.name, ^pattern) or
            ilike(r.email, ^pattern) or
            ilike(r.organization, ^pattern)
      )
    else
      filtered
    end
    |> Repo.all()
  end

  # ── CSV ───────────────────────────────────────────────────────────────────────

  @csv_headers [
    "Name",
    "Email",
    "Organization",
    "Job Title",
    "Treasury Volume (USD)",
    "Subsidiaries",
    "Message",
    "Status",
    "Confidence %",
    "Submitted",
    "Reviewed By",
    "Approved By",
    "Rejected By",
    "Rejection Reason"
  ]

  defp build_csv(requests) do
    rows = Enum.map(requests, &request_to_row/1)

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

  # ── Excel ─────────────────────────────────────────────────────────────────────

  defp build_xlsx(requests) do
    rows = Enum.map(requests, &request_to_row/1)

    sheet = %Elixlsx.Sheet{name: "Access Requests", rows: [@csv_headers | rows]}
    workbook = %Elixlsx.Workbook{sheets: [sheet]}

    {:ok, {_filename, data}} = Elixlsx.write_to_memory(workbook, "access_requests.xlsx")
    data
  end

  # ── Shared row builder ────────────────────────────────────────────────────────

  defp request_to_row(r) do
    [
      r.name,
      r.email,
      r.organization || "",
      r.job_title || "",
      format_volume(r.treasury_volume),
      format_subsidiaries(r.subsidiaries),
      r.message || "",
      r.status,
      confidence_score(r),
      Calendar.strftime(r.created_at, "%Y-%m-%d"),
      r.reviewed_by || "",
      r.approved_by || "",
      r.rejected_by || "",
      r.rejection_reason || ""
    ]
  end

  # ── Auth plug ─────────────────────────────────────────────────────────────────

  # The :browser pipeline already runs UserAuth which sets current_user.
  # This plug simply refuses the request if no user was resolved.
  defp ensure_authenticated(conn, _opts),
    do: NexusWeb.UserAuth.require_authenticated(conn, [])

  # ── Formatters ────────────────────────────────────────────────────────────────

  defp format_volume("lt_10m"), do: "< $10M"
  defp format_volume("10m_100m"), do: "$10M – $100M"
  defp format_volume("100m_500m"), do: "$100M – $500M"
  defp format_volume("500m_1b"), do: "$500M – $1B"
  defp format_volume("gt_1b"), do: "> $1B"
  defp format_volume(v), do: v || ""

  defp format_subsidiaries("1_5"), do: "1 – 5"
  defp format_subsidiaries("6_20"), do: "6 – 20"
  defp format_subsidiaries("21_50"), do: "21 – 50"
  defp format_subsidiaries("51_100"), do: "51 – 100"
  defp format_subsidiaries("100_plus"), do: "100+"
  defp format_subsidiaries(v), do: v || ""

  defp confidence_score(request) do
    score =
      volume_score(request.treasury_volume) +
        subsidiary_score(request.subsidiaries) +
        message_score(request.message) +
        email_score(request.email) +
        org_score(request.organization)

    min(score, 100)
  end

  defp volume_score("gt_1b"), do: 40
  defp volume_score("500m_1b"), do: 32
  defp volume_score("100m_500m"), do: 22
  defp volume_score("10m_100m"), do: 12
  defp volume_score("lt_10m"), do: 4
  defp volume_score(_), do: 0

  defp subsidiary_score("100_plus"), do: 20
  defp subsidiary_score("51_100"), do: 16
  defp subsidiary_score("21_50"), do: 11
  defp subsidiary_score("6_20"), do: 6
  defp subsidiary_score("1_5"), do: 2
  defp subsidiary_score(_), do: 0

  defp message_score(msg) when is_binary(msg), do: if(String.trim(msg) != "", do: 15, else: 0)
  defp message_score(_), do: 0

  defp email_score(email), do: if(work_email?(email), do: 15, else: 0)

  defp org_score(org) when is_binary(org), do: if(String.length(org) > 5, do: 10, else: 0)
  defp org_score(_), do: 0

  @free_domains ~w(gmail.com yahoo.com hotmail.com outlook.com icloud.com)

  defp work_email?(email) do
    case String.split(email, "@") do
      [_, domain] -> domain not in @free_domains
      _ -> false
    end
  end
end
