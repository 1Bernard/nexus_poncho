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
       |> assign(:filter, "all")}
    else
      {:ok,
       socket
       |> put_flash(:error, "You do not have permission to view the compliance dashboard.")
       |> redirect(to: ~p"/vaults")}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app
      flash={@flash}
      current_user={@current_user}
      page_title={@page_title}
      breadcrumb_section="Compliance"
    >
      <div class="p-8 bg-[#010101] min-h-full">
        <div class="max-w-6xl mx-auto space-y-8">
          <%!-- Header --%>
          <div>
            <p class="text-[8px] font-mono text-zinc-600 uppercase tracking-[0.3em] mb-2">
              COMPLIANCE · OVERSIGHT
            </p>
            <h1 class="text-2xl font-serif font-bold text-white">Compliance Dashboard</h1>
            <p class="text-[10px] font-mono text-zinc-500 mt-1">
              PEP screening status, flagged entities, and audit trail
            </p>
          </div>

          <%!-- Stats row --%>
          <div class="grid grid-cols-3 gap-4">
            <div class="prestige-card rounded-2xl p-6">
              <p class="text-[8px] font-mono text-zinc-600 uppercase tracking-[0.25em] mb-3">
                Clean Screenings
              </p>
              <p class="text-3xl font-serif font-bold text-emerald-400">
                {@screening_stats.clean}
              </p>
              <p class="text-[9px] font-mono text-zinc-500 mt-1 uppercase tracking-widest">
                PEP Cleared
              </p>
            </div>
            <div class="prestige-card rounded-2xl p-6">
              <p class="text-[8px] font-mono text-zinc-600 uppercase tracking-[0.25em] mb-3">
                Pending Review
              </p>
              <p class="text-3xl font-serif font-bold text-amber-400">
                {@screening_stats.pending}
              </p>
              <p class="text-[9px] font-mono text-zinc-500 mt-1 uppercase tracking-widest">
                Awaiting Clearance
              </p>
            </div>
            <div class="prestige-card rounded-2xl p-6">
              <p class="text-[8px] font-mono text-zinc-600 uppercase tracking-[0.25em] mb-3">
                Flagged Entities
              </p>
              <p class="text-3xl font-serif font-bold text-rose-400">
                {@screening_stats.flagged}
              </p>
              <p class="text-[9px] font-mono text-zinc-500 mt-1 uppercase tracking-widest">
                Requires Action
              </p>
            </div>
          </div>

          <%!-- Two-column layout --%>
          <div class="grid grid-cols-[1fr_380px] gap-6">
            <%!-- Screening table --%>
            <div class="prestige-card rounded-2xl overflow-hidden">
              <div class="px-6 py-4 border-b border-white/5 flex items-center justify-between">
                <p class="text-[10px] font-mono text-zinc-300 uppercase tracking-widest font-bold">
                  PEP Screenings
                </p>
                <div class="flex gap-2">
                  <%= for {label, val} <- [{"All", "all"}, {"Flagged", "flagged"}, {"Pending", "pending"}] do %>
                    <button
                      phx-click="filter"
                      phx-value-status={val}
                      class={[
                        "text-[8px] font-mono uppercase tracking-widest px-3 py-1 rounded-full transition-colors",
                        @filter == val &&
                          "bg-emerald-400/20 text-emerald-400 border border-emerald-400/30",
                        @filter != val && "text-zinc-600 hover:text-zinc-400"
                      ]}
                    >
                      {label}
                    </button>
                  <% end %>
                </div>
              </div>

              <%!-- Screening list --%>
              <div class="divide-y divide-white/5">
                <%= if filtered_screenings(@screenings, @filter) == [] do %>
                  <div class="px-6 py-8 text-center">
                    <p class="text-[10px] font-mono text-zinc-600 uppercase tracking-widest">
                      No screenings found
                    </p>
                  </div>
                <% end %>
                <%= for screening <- filtered_screenings(@screenings, @filter) do %>
                  <div class="px-6 py-4 flex items-center justify-between hover:bg-white/[0.02] transition-colors">
                    <div class="flex items-center gap-3">
                      <div class={[
                        "w-2 h-2 rounded-full flex-shrink-0",
                        screening.status == "clean" && "bg-emerald-400 shadow-[0_0_6px_#34d399]",
                        screening.status == "pending" && "bg-amber-400 shadow-[0_0_6px_#fbbf24]",
                        screening.status == "flagged" && "bg-rose-400 shadow-[0_0_6px_#f87171]"
                      ]}>
                      </div>
                      <div>
                        <p class="text-[11px] font-bold text-white">{screening.name}</p>
                        <p class="text-[9px] font-mono text-zinc-500">
                          Org: {String.slice(screening.org_id, 0, 8)}...
                        </p>
                      </div>
                    </div>
                    <span class={[
                      "text-[8px] font-mono uppercase tracking-widest px-2 py-0.5 rounded-full",
                      screening.status == "clean" &&
                        "text-emerald-400 bg-emerald-400/10 border border-emerald-400/20",
                      screening.status == "pending" &&
                        "text-amber-400 bg-amber-400/10 border border-amber-400/20",
                      screening.status == "flagged" &&
                        "text-rose-400 bg-rose-400/10 border border-rose-400/20"
                    ]}>
                      {screening.status}
                    </span>
                  </div>
                <% end %>
              </div>
            </div>

            <%!-- Right column --%>
            <div class="space-y-6">
              <%!-- Flagged access requests --%>
              <div class="prestige-card rounded-2xl overflow-hidden">
                <div class="px-6 py-4 border-b border-white/5">
                  <p class="text-[10px] font-mono text-zinc-300 uppercase tracking-widest font-bold">
                    Flagged Access Requests
                  </p>
                </div>
                <div class="divide-y divide-white/5">
                  <%= if @flagged_requests == [] do %>
                    <div class="px-6 py-6 text-center">
                      <p class="text-[9px] font-mono text-zinc-600 uppercase tracking-widest">
                        None flagged
                      </p>
                    </div>
                  <% end %>
                  <%= for req <- @flagged_requests do %>
                    <div class="px-6 py-3">
                      <p class="text-[10px] font-bold text-white">{req.name}</p>
                      <p class="text-[9px] font-mono text-zinc-500">{req.organization}</p>
                      <span class="text-[8px] font-mono text-rose-400 uppercase tracking-widest">
                        {req.sanctions_screening || "flagged"}
                      </span>
                    </div>
                  <% end %>
                </div>
              </div>

              <%!-- Recent audit events --%>
              <div class="prestige-card rounded-2xl overflow-hidden">
                <div class="px-6 py-4 border-b border-white/5">
                  <p class="text-[10px] font-mono text-zinc-300 uppercase tracking-widest font-bold">
                    Recent Audit Events
                  </p>
                </div>
                <div class="divide-y divide-white/5">
                  <%= if @recent_audit == [] do %>
                    <div class="px-6 py-6 text-center">
                      <p class="text-[9px] font-mono text-zinc-600 uppercase tracking-widest">
                        No events recorded
                      </p>
                    </div>
                  <% end %>
                  <%= for entry <- @recent_audit do %>
                    <div class="px-6 py-3">
                      <p class="text-[9px] font-mono text-zinc-300 uppercase tracking-widest">
                        {entry.event_type}
                      </p>
                      <p class="text-[8px] font-mono text-zinc-600">
                        {Calendar.strftime(entry.recorded_at, "%d %b %Y %H:%M")}
                      </p>
                    </div>
                  <% end %>
                </div>
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
    {:noreply, assign(socket, :filter, status)}
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
