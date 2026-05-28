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
    filtered = filtered_screenings(assigns.screenings, assigns.filter)
    total_count = length(filtered)
    total_pages = max(1, ceil(total_count / assigns.per_page))
    paginated = Enum.slice(filtered, (assigns.page - 1) * assigns.per_page, assigns.per_page)

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

        <div class="max-w-7xl mx-auto space-y-10 relative z-10">
          <.eq_control_bar>
            <.eq_control_cluster>
              <div class="flex items-center pl-4">
                <.icon name="hero-magnifying-glass-mini" class="w-4 h-4 text-emerald-400/50" />
                <input
                  type="text"
                  placeholder="FILTER SCREENINGS..."
                  class="search-input py-2.5 px-4 text-[10px] font-mono font-bold text-white placeholder:text-zinc-700 focus:outline-none uppercase tracking-widest"
                />
              </div>
            </.eq_control_cluster>

            <.eq_control_cluster>
              <div class="flex items-center gap-1 p-1">
                <%= for {label, val} <- [{"All", "all"}, {"Flagged", "flagged"}, {"Pending", "pending"}] do %>
                  <button
                    phx-click="filter"
                    phx-value-status={val}
                    class={[
                      "text-[8px] font-mono font-black uppercase tracking-[0.2em] px-5 py-2 rounded-lg transition-all duration-300",
                      @filter == val &&
                        "bg-emerald-400 text-black shadow-[0_0_20px_rgba(52,211,153,0.2)]",
                      @filter != val && "text-zinc-500 hover:text-white hover:bg-white/5"
                    ]}
                  >
                    {label}
                  </button>
                <% end %>
              </div>
            </.eq_control_cluster>
          </.eq_control_bar>

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

          <%!-- Two-column layout --%>
          <div class="grid grid-cols-[1fr_400px] gap-10">
            <%!-- Screening table --%>
            <div class="space-y-6 flex flex-col min-h-0">
              <div class="flex items-center gap-4 px-2">
                <h3 class="text-[10px] font-black uppercase tracking-[0.4em] text-white/30">
                  Compliance Ledger
                </h3>
                <div class="h-px flex-1 bg-white/[0.03]"></div>
              </div>

              <div class="elite-border rounded-3xl bg-[#050508]/60 backdrop-blur-2xl overflow-hidden flex-1 flex flex-col min-h-0 border border-white/5 shadow-2xl">
                <div class="overflow-auto flex-1 custom-scrollbar">
                  <%= if @total_count == 0 do %>
                    <.ledger_empty_state
                      title="No matching screenings found"
                      subtitle="All entity identities have been cleared or filtered out."
                      action_label={if @filter != "all", do: "Reset Filter", else: nil}
                      action_event={if @filter != "all", do: "reset_filter", else: nil}
                    />
                  <% else %>
                    <.ledger_table id="screening-ledger" rows={@paginated_screenings}>
                      <:col :let={screening} label="Identity Profile">
                        <div class="flex items-center gap-5 relative">
                          <div class="grid-guide-v -left-6"></div>
                          <div class="grid-guide-h top-0"></div>
                          <div class="grid-guide-h bottom-0"></div>
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

            <%!-- Right column --%>
            <div class="space-y-10">
              <%!-- Flagged access requests --%>
              <div class="space-y-6">
                <div class="flex items-center gap-4 px-2">
                  <h3 class="text-[10px] font-black uppercase tracking-[0.4em] text-rose-400/40">
                    High-Risk Alerts
                  </h3>
                  <div class="h-px flex-1 bg-rose-400/10"></div>
                </div>
                <.prestige_card class="p-0 border-rose-500/10 shadow-[0_20px_50px_rgba(244,63,94,0.05)]">
                  <div class="divide-y divide-white/5">
                    <%= if @flagged_requests == [] do %>
                      <div class="p-12 text-center opacity-30">
                        <p class="text-[10px] font-mono text-zinc-500 uppercase tracking-[0.3em]">
                          Threat level: Zero
                        </p>
                      </div>
                    <% end %>
                    <%= for req <- @flagged_requests do %>
                      <div class="p-6 group hover:bg-rose-500/[0.03] transition-colors relative cursor-pointer">
                        <div class="absolute left-0 top-0 w-0.5 h-full bg-rose-500 opacity-0 group-hover:opacity-100 transition-opacity">
                        </div>
                        <div class="flex justify-between items-start mb-2">
                          <p class="text-xs font-black text-white uppercase tracking-tight">
                            {req.name}
                          </p>
                          <span class="text-[8px] font-mono font-black text-rose-400 uppercase bg-rose-400/10 px-2 py-0.5 rounded border border-rose-400/20">
                            FLAGGED
                          </span>
                        </div>
                        <p class="text-[10px] font-mono text-zinc-500 mb-3">{req.organization}</p>
                        <div class="flex items-center gap-2">
                          <.icon
                            name="hero-shield-exclamation-mini"
                            class="w-3.5 h-3.5 text-rose-500/50"
                          />
                          <p class="text-[9px] font-mono text-rose-400/70 uppercase tracking-widest font-bold">
                            {req.sanctions_screening || "Manual Audit Flag"}
                          </p>
                        </div>
                      </div>
                    <% end %>
                  </div>
                </.prestige_card>
              </div>

              <%!-- Recent audit events --%>
              <div class="space-y-6">
                <div class="flex items-center gap-4 px-2">
                  <h3 class="text-[10px] font-black uppercase tracking-[0.4em] text-white/20">
                    System Audit
                  </h3>
                  <div class="h-px flex-1 bg-white/[0.03]"></div>
                </div>
                <.prestige_card class="p-0 border-white/[0.03]">
                  <div class="divide-y divide-white/5">
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
                          <div class="w-1 h-1 rounded-full bg-zinc-800 group-hover:bg-emerald-400/50 transition-colors">
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
      </div>
    </Layouts.app>
    """
  end

  @impl true
  def handle_event("filter", %{"status" => status}, socket) do
    {:noreply, assign(socket, filter: status, page: 1)}
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

    %{
      clean: Map.get(counts, "clean", 0),
      pending: Map.get(counts, "pending", 0),
      flagged: Map.get(counts, "flagged", 0)
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
        where: not is_nil(r.sanctions_screening) and r.sanctions_screening != "clear",
        order_by: [desc: r.created_at],
        limit: 10
      )
    )
  end

  defp filtered_screenings(screenings, "all"), do: screenings

  defp filtered_screenings(screenings, status),
    do: Enum.filter(screenings, &(&1.status == status))

  defp can_view_compliance?(user) do
    user.role in ~w(compliance_officer org_admin group_treasurer admin) ||
      user.platform_role in ~w(super_admin platform_support)
  end
end
