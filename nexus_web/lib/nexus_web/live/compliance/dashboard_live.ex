defmodule NexusWeb.Compliance.DashboardLive do
  use NexusWeb, :live_view

  import Ecto.Query

  alias Nexus.Compliance.Projections.{AuditLog, Screening}
  alias Nexus.Marketing.Projections.AccessRequest
  alias Nexus.Repo

  require Logger

  @impl true
  def mount(_params, _session, socket) do
    user = socket.assigns.current_user

    if user && can_view_compliance?(user) do
      {:ok,
       socket
       |> assign(:page_title, "Compliance Dashboard")
       |> assign(:screenings, load_screenings())
       |> assign(:screening_stats, compute_screening_stats())
       |> assign(:recent_audit, load_recent_audit())
       |> assign(:flagged_requests, load_flagged_requests())
       |> assign(:filter, "all")
       |> assign(:search, "")
       |> assign(:show_filters, false)
       |> assign(:page, 1)
       |> assign(:per_page, 10)}
    else
      {:ok,
       socket
       |> put_flash(:error, "You do not have permission to view the compliance dashboard.")
       |> redirect(to: ~p"/vaults")}
    end
  end

  @impl true
  def render(assigns) do
    all_screenings = filtered_screenings(assigns.screenings, assigns.filter, assigns.search)
    total_count = length(all_screenings)
    total_pages = max(1, ceil(total_count / assigns.per_page))

    paginated =
      Enum.slice(all_screenings, (assigns.page - 1) * assigns.per_page, assigns.per_page)

    assigns =
      assigns
      |> assign(:total_count, total_count)
      |> assign(:total_pages, total_pages)
      |> assign(:paginated_screenings, paginated)

    ~H"""
    <Layouts.app
      flash={@flash}
      current_user={@current_user}
      page_title={@page_title}
      breadcrumb_section="Compliance"
    >
      <div class="p-8 bg-[#010101] min-h-full relative overflow-hidden">
        <div class="bg-grid-elite"></div>

        <div class="max-w-7xl mx-auto space-y-8 relative z-10">
          <%!-- HUD Stats Ribbon --%>
          <div class="grid grid-cols-3 gap-8">
            <.hud_metric_card
              label="Clean Screenings"
              value={@screening_stats.clean}
              color="emerald"
              status="PEP CLEARED"
            />
            <.hud_metric_card
              label="Pending Review"
              value={@screening_stats.pending}
              color="amber"
              status="AWAITING CLEARANCE"
            />
            <.hud_metric_card
              label="Flagged Entities"
              value={@screening_stats.flagged}
              color="rose"
              status="REQUIRES ACTION"
            />
          </div>

          <%!-- High-Risk Alerts --%>
          <div class="space-y-4">
            <div class="flex items-center gap-4 px-2">
              <h3 class={[
                "text-[10px] font-black uppercase tracking-[0.4em]",
                if(@flagged_requests != [], do: "text-rose-400", else: "text-zinc-500")
              ]}>
                High-Risk Alerts
              </h3>
              <div class={[
                "h-px flex-1",
                if(@flagged_requests != [], do: "bg-rose-500/10", else: "bg-white/[0.03]")
              ]}>
              </div>
              <span
                :if={@flagged_requests != []}
                class="text-[8px] font-mono font-bold text-rose-400 bg-rose-400/10 px-2 py-0.5 rounded border border-rose-400/20 uppercase tracking-widest"
              >
                Action Required
              </span>
            </div>

            <%= if @flagged_requests == [] do %>
              <div class="flex flex-col items-center justify-center p-12 rounded-2xl bg-[#050508]/40 border border-white/5 shadow-2xl relative overflow-hidden group">
                <div class="absolute inset-0 bg-gradient-to-r from-emerald-500/0 via-emerald-500/[0.01] to-emerald-500/0 translate-x-[-100%] group-hover:translate-x-[100%] transition-transform duration-1000 ease-out">
                </div>
                <.icon name="hero-shield-check" class="size-8 text-emerald-400/40 mb-3" />
                <p class="text-[10px] font-mono text-zinc-500 uppercase tracking-[0.3em]">
                  Threat level: Zero
                </p>
                <p class="text-[9px] font-mono text-zinc-600 uppercase mt-1">
                  All active sanctions screenings cleared · system secure
                </p>
              </div>
            <% else %>
              <div class="grid grid-cols-1 md:grid-cols-2 gap-6">
                <%= for req <- @flagged_requests do %>
                  <div
                    phx-click={JS.patch(~p"/admin/access-requests")}
                    class="relative p-5 rounded-xl bg-[#09090b]/40 border border-white/5 hover:border-rose-500/20 hover:bg-rose-500/[0.01] transition-all duration-300 group cursor-pointer"
                  >
                    <div class="flex justify-between items-start gap-4">
                      <div class="flex items-start gap-3">
                        <div class="mt-1 w-1.5 h-1.5 rounded-full bg-rose-500 shadow-[0_0_8px_#f43f5e] animate-pulse">
                        </div>
                        <div>
                          <p class="text-xs font-bold text-zinc-200 group-hover:text-rose-400 transition-colors tracking-tight">
                            {req.name}
                          </p>
                          <p class="text-[10px] font-mono text-zinc-500 mt-0.5">{req.organization}</p>
                        </div>
                      </div>

                      <span class="text-[8px] font-mono font-bold text-rose-400 bg-rose-950/20 border border-rose-800/30 px-2 py-0.5 rounded tracking-widest uppercase">
                        {req.sanctions_screening}
                      </span>
                    </div>

                    <div class="mt-3.5 pt-3 border-t border-white/[0.02] flex items-center justify-between">
                      <div class="flex items-center gap-1.5">
                        <.icon name="hero-shield-exclamation" class="w-3 h-3 text-rose-500/60" />
                        <span class="text-[8px] font-mono text-zinc-500 uppercase tracking-wider">
                          Threat Level: Critical
                        </span>
                      </div>

                      <span class="text-[9px] font-mono text-zinc-500 group-hover:text-zinc-300 transition-colors flex items-center gap-1">
                        Triage Queue
                        <.icon
                          name="hero-chevron-right-mini"
                          class="w-3 h-3 group-hover:translate-x-0.5 transition-transform"
                        />
                      </span>
                    </div>
                  </div>
                <% end %>
              </div>
            <% end %>
          </div>

          <%!-- Split bottom layout --%>
          <div class="grid grid-cols-1 lg:grid-cols-[1fr_360px] gap-10">
            <%!-- Left Column: Table Ledger --%>
            <div class="space-y-6 flex flex-col min-h-0">
              <div class="flex items-center gap-4 px-2">
                <h3 class="text-[10px] font-black uppercase tracking-[0.4em] text-white/30">
                  Compliance Ledger
                </h3>
                <div class="h-px flex-1 bg-white/[0.03]"></div>
              </div>

              <%!-- Compliance Ledger toolbar --%>
              <.eq_table_toolbar
                search_value={@search}
                search_event="search"
                search_name="query"
                search_placeholder="Search screenings..."
                show_refine={true}
                show_filters={@show_filters}
                filter_active={@filter != "all"}
              >
                <:filter_panel>
                  <div class="flex justify-between items-center mb-4">
                    <h4 class="text-[10px] font-bold tracking-widest text-zinc-500 uppercase">
                      Status Filter
                    </h4>
                    <button
                      phx-click="filter"
                      phx-value-status="all"
                      class="text-[9px] font-bold text-emerald-400 hover:underline"
                    >
                      Reset
                    </button>
                  </div>
                  <div class="flex flex-col gap-2">
                    <%= for {label, val} <- [{"All", "all"}, {"Flagged", "flagged"}, {"Pending", "pending"}, {"Clean", "clean"}] do %>
                      <button
                        phx-click="filter"
                        phx-value-status={val}
                        class={[
                          "w-full py-2 px-4 rounded-lg border text-[10px] font-mono font-bold uppercase tracking-widest text-left transition-all",
                          @filter == val && "bg-emerald-400/15 border-emerald-400/30 text-emerald-400",
                          @filter != val &&
                            "border-white/10 text-zinc-400 hover:bg-white/5 hover:text-white"
                        ]}
                      >
                        {label}
                      </button>
                    <% end %>
                  </div>
                </:filter_panel>

                <:actions>
                  <div class="relative">
                    <button
                      phx-click={JS.toggle(to: "#export-dropdown")}
                      class="flex items-center gap-2 px-4 py-2 rounded-lg hover:bg-white/5 text-[10px] font-bold text-zinc-400 hover:text-white transition-all uppercase tracking-widest"
                    >
                      <.icon name="hero-arrow-down-tray-mini" class="w-3.5 h-3.5" />
                      <span class="hidden md:inline">Export</span>
                      <.icon name="hero-chevron-down-mini" class="w-3 h-3 opacity-50" />
                    </button>
                    <div
                      id="export-dropdown"
                      class="hidden absolute right-0 top-full mt-2 w-44 rounded-xl bg-[#0a0a0f] border border-white/10 p-2 z-50 shadow-2xl"
                    >
                      <a
                        href={
                          ~p"/compliance/screenings/export?format=csv&status=#{@filter}&search=#{@search}"
                        }
                        class="flex items-center gap-2.5 px-3 py-2.5 rounded-lg text-[10px] font-bold text-zinc-400 hover:text-white hover:bg-white/5 transition-all"
                      >
                        <.icon name="hero-document-text-mini" class="w-3.5 h-3.5" /> CSV
                      </a>
                      <a
                        href={
                          ~p"/compliance/screenings/export?format=xlsx&status=#{@filter}&search=#{@search}"
                        }
                        class="flex items-center gap-2.5 px-3 py-2.5 rounded-lg text-[10px] font-bold text-zinc-400 hover:text-white hover:bg-white/5 transition-all"
                      >
                        <.icon name="hero-table-cells-mini" class="w-3.5 h-3.5" /> Excel (.xlsx)
                      </a>
                    </div>
                  </div>
                </:actions>
              </.eq_table_toolbar>

              <div class="elite-border rounded-2xl bg-[#050508]/60 backdrop-blur-2xl overflow-hidden flex-1 flex flex-col min-h-0 border border-white/5 shadow-2xl">
                <div class="overflow-auto flex-1 custom-scrollbar">
                  <%= if @total_count == 0 do %>
                    <.ledger_empty_state
                      title="No matching screenings found"
                      subtitle="All entity identities have been cleared or filtered out."
                      action_label={if @filter != "all", do: "Reset Filter", else: nil}
                      action_event={if @filter != "all", do: "reset_filter", else: nil}
                    />
                  <% else %>
                    <.ledger_table
                      id="screening-ledger"
                      rows={@paginated_screenings}
                      grid_guides={true}
                    >
                      <:col :let={screening} label="Identity Profile">
                        <div class="flex items-center gap-5">
                          <div class={[
                            "w-2 h-2 rounded-full flex-shrink-0 shadow-lg",
                            screening.status == "clean" && "bg-emerald-400",
                            screening.status == "pending" && "bg-amber-400",
                            screening.status == "flagged" && "bg-rose-400"
                          ]}>
                          </div>
                          <div>
                            <p class="text-sm font-black text-white tracking-tight">
                              {screening.name}
                            </p>
                            <p class="text-[9px] font-mono text-zinc-500 uppercase tracking-widest mt-0.5">
                              UID: {String.slice(screening.id, 0, 12)}
                            </p>
                          </div>
                        </div>
                      </:col>

                      <:col :let={screening} label="Entity Association">
                        <div class="flex items-center gap-2">
                          <span class="text-[10px] font-mono font-bold text-zinc-400 uppercase tracking-widest">
                            {String.slice(screening.org_id, 0, 16)}
                          </span>
                        </div>
                      </:col>

                      <:col :let={screening} label="Audit Result">
                        <.status_pill status={screening.status} />
                      </:col>

                      <:action :let={_screening}>
                        <button class="p-2.5 rounded-lg bg-white/5 text-zinc-500 hover:text-emerald-400 hover:bg-emerald-400/10 transition-all group">
                          <.icon
                            name="hero-finger-print-mini"
                            class="w-4 h-4 group-hover:scale-110 transition-transform"
                          />
                        </button>
                      </:action>
                    </.ledger_table>
                  <% end %>
                </div>
                <.ledger_pagination
                  page={@page}
                  per_page={@per_page}
                  total_count={@total_count}
                  total_pages={@total_pages}
                  extra_label="Clean"
                  extra_count={@screening_stats.clean}
                />
              </div>
            </div>

            <%!-- Right Column: System Audit --%>
            <div class="space-y-6 flex flex-col min-h-0">
              <div class="flex items-center gap-4 px-2">
                <h3 class="text-[10px] font-black uppercase tracking-[0.4em] text-white/20">
                  System Audit
                </h3>
                <div class="h-px flex-1 bg-white/[0.03]"></div>
              </div>
              <.prestige_card class="p-0 border-white/[0.03] flex-1 flex flex-col min-h-0 overflow-hidden">
                <div class="divide-y divide-white/5 overflow-auto custom-scrollbar flex-1">
                  <%= if @recent_audit == [] do %>
                    <div class="p-12 text-center opacity-20">
                      <p class="text-[10px] font-mono text-zinc-500 uppercase tracking-[0.3em]">
                        Awaiting entry
                      </p>
                    </div>
                  <% end %>
                  <%= for entry <- @recent_audit do %>
                    <div class="p-5 hover:bg-white/[0.02] transition-all group">
                      <div class="flex justify-between items-center mb-1">
                        <p class="text-[10px] font-mono font-black text-zinc-400 uppercase tracking-widest group-hover:text-emerald-400 transition-colors">
                          {entry.event_type}
                        </p>
                        <p class="text-[9px] font-mono text-zinc-600 uppercase tabular-nums">
                          {Calendar.strftime(entry.recorded_at, "%H:%M:%S")}
                        </p>
                      </div>
                      <div class="flex items-center gap-2">
                        <div class="w-1.5 h-1.5 rounded-full bg-zinc-800 group-hover:bg-emerald-400/50 transition-colors">
                        </div>
                        <p class="text-[8px] font-mono text-zinc-700 uppercase tracking-widest">
                          {Calendar.strftime(entry.recorded_at, "%d %b %Y")} · TRACE_ID: {String.slice(
                            entry.id |> to_string,
                            0,
                            8
                          )}
                        </p>
                      </div>
                    </div>
                  <% end %>
                </div>
              </.prestige_card>
            </div>
          </div>
        </div>
      </div>
    </Layouts.app>
    """
  end

  @impl true
  def handle_event("search", %{"query" => query}, socket) do
    {:noreply, assign(socket, search: query, page: 1)}
  end

  @impl true
  def handle_event("toggle_filters", _params, socket) do
    {:noreply, assign(socket, show_filters: !socket.assigns.show_filters)}
  end

  @impl true
  def handle_event("close_filters", _params, socket) do
    {:noreply, assign(socket, show_filters: false)}
  end

  @impl true
  def handle_event("filter", %{"status" => status}, socket) do
    {:noreply, assign(socket, filter: status, page: 1, show_filters: false)}
  end

  @impl true
  def handle_event("reset_filter", _params, socket) do
    {:noreply, assign(socket, filter: "all", page: 1)}
  end

  @impl true
  def handle_event("paginate", %{"page" => page}, socket) do
    page =
      case Integer.parse(to_string(page)) do
        {p, _} -> max(1, p)
        :error -> 1
      end

    {:noreply, assign(socket, :page, page)}
  end

  @impl true
  def handle_event("change_page_size", %{"page_size" => size}, socket) do
    per_page =
      case Integer.parse(to_string(size)) do
        {s, _} -> s
        :error -> 10
      end

    {:noreply, assign(socket, per_page: per_page, page: 1)}
  end

  # ── Private ─────────────────────────────────────────────────────────────────

  defp load_screenings do
    Repo.all(from(s in Screening, order_by: [asc: s.status, asc: s.name], limit: 100))
  end

  defp compute_screening_stats do
    counts =
      Repo.all(
        from(s in Screening,
          group_by: s.status,
          select: {s.status, count(s.id)}
        )
      )
      |> Map.new()

    flagged_req_count =
      Repo.one(
        from(r in AccessRequest,
          where: r.sanctions_screening == "flagged",
          select: count(r.id)
        )
      ) || 0

    %{
      clean: Map.get(counts, "clean", 0),
      pending: Map.get(counts, "pending", 0),
      flagged: flagged_req_count
    }
  end

  defp load_recent_audit do
    Repo.all(
      from(a in AuditLog,
        order_by: [desc: a.recorded_at],
        limit: 10
      )
    )
  end

  defp load_flagged_requests do
    Repo.all(
      from(r in AccessRequest,
        where: r.sanctions_screening == "flagged",
        order_by: [desc: r.created_at],
        limit: 10
      )
    )
  end

  defp filtered_screenings(screenings, "all", ""), do: screenings

  defp filtered_screenings(screenings, status, ""),
    do: Enum.filter(screenings, &(&1.status == status))

  defp filtered_screenings(screenings, "all", query) do
    q = String.downcase(query)
    Enum.filter(screenings, &String.contains?(String.downcase(&1.name), q))
  end

  defp filtered_screenings(screenings, status, query) do
    q = String.downcase(query)

    Enum.filter(
      screenings,
      &(&1.status == status and String.contains?(String.downcase(&1.name), q))
    )
  end

  defp can_view_compliance?(user) do
    user.role in ~w(compliance_officer org_admin group_treasurer admin) ||
      user.platform_role in ~w(super_admin platform_support)
  end
end
