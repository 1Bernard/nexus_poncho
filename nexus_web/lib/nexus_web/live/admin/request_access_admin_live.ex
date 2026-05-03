defmodule NexusWeb.Admin.RequestAccessAdminLive do
  use NexusWeb, :live_view

  import Ecto.Query

  alias Nexus.App
  alias Nexus.Identity.WebAuthn.BiometricInvitation

  alias Nexus.Marketing.Commands.{
    ApproveAccessRequest,
    ArchiveAccessRequest,
    RejectAccessRequest,
    ReviewAccessRequest
  }

  alias Nexus.Marketing.Projections.AccessRequest
  alias Nexus.Repo
  alias Nexus.Shared.Tracing
  alias NexusShared.Identity.Roles

  @per_page 20
  @statuses ~w(pending under_review approved rejected archived)

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(
       page_title: "Access Requests",
       breadcrumb_section: "Admin",
       page: 1,
       filter_status: "all",
       search: "",
       selected_ids: MapSet.new(),
       show_drawer: false,
       show_filters: false,
       drawer_request: nil,
       invitation_link: nil,
       approve_role: "",
       show_reject_form: false,
       reject_reason: "",
       show_bulk_reject_form: false,
       bulk_reject_reason: "",
       total_count: 0,
       total_pages: 1,
       per_page: @per_page,
       statuses: @statuses,
       current_page_ids: [],
       view_mode: "list",
       duplicate_warnings: []
     )
     |> load_requests()}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app
      flash={@flash}
      current_user={@current_user}
      current_scope={:admin}
      page_title={@page_title}
      breadcrumb_section={@breadcrumb_section}
    >
      <div class="min-h-full p-8 flex flex-col relative bg-[#010101]">
        <div class="bg-grid-elite"></div>

        <%!-- TOAST NOTIFICATIONS --%>
        <%!-- Success: shown/hidden purely by JS via push_event("toast:show:success") --%>
        <div id="toast-success" class="floating-toast">
          <i data-lucide="check-circle-2" class="w-4 h-4 text-emerald-400"></i>
          <span
            id="toast-success-msg"
            class="text-[10px] font-bold uppercase tracking-widest text-white/90"
          >
            Operation successful
          </span>
        </div>
        <%!-- Error: server-driven via @flash so it persists until explicitly dismissed --%>
        <div
          id="toast-error"
          class={["floating-toast floating-toast--error", @flash[:error] && "visible"]}
        >
          <i data-lucide="alert-circle" class="w-4 h-4 text-rose-400"></i>
          <span class="text-[10px] font-bold uppercase tracking-widest text-rose-300">
            {@flash[:error] || "An error occurred"}
          </span>
        </div>

        <%!-- BATCH ACTION BAR --%>
        <div
          id="batch-actions"
          class={[
            "batch-actions-elite fixed bottom-8 left-1/2 -translate-x-1/2 z-[35] bg-[#0a0a0f]/90 backdrop-blur-xl border border-white/10 rounded-2xl px-6 py-4 flex items-center gap-6 shadow-2xl",
            MapSet.size(@selected_ids) > 0 && "visible"
          ]}
        >
          <div class="flex items-center gap-3 pr-6 border-r border-white/10">
            <i data-lucide="layers" class="w-4 h-4 text-emerald-400"></i>
            <span class="text-xs font-mono font-bold text-white">
              {MapSet.size(@selected_ids)} selected
            </span>
          </div>

          <%= if @show_bulk_reject_form do %>
            <%!-- Bulk reject reason capture --%>
            <div class="flex items-center gap-3">
              <input
                type="text"
                phx-change="set_bulk_reject_reason"
                name="bulk_reason"
                value={@bulk_reject_reason}
                placeholder="AUDIT REASON FOR REJECTION..."
                class="bg-black/40 border border-rose-400/30 rounded-xl py-2.5 px-4 text-[10px] font-mono text-white placeholder:text-zinc-700 focus:outline-none focus:border-rose-400/60 w-72 uppercase tracking-wider"
              />
              <button
                phx-click="bulk_reject"
                disabled={String.trim(@bulk_reject_reason) == ""}
                class="flex items-center gap-2 text-[10px] font-black uppercase tracking-wider text-rose-400 hover:text-rose-300 transition-all disabled:opacity-30"
              >
                <i data-lucide="check" class="w-3.5 h-3.5"></i> Confirm
              </button>
              <button
                phx-click="cancel_bulk_reject"
                class="text-[9px] font-mono text-zinc-500 hover:text-white uppercase tracking-wider"
              >
                Cancel
              </button>
            </div>
          <% else %>
            <div class="flex items-center gap-4">
              <button
                phx-click="bulk_under_review"
                class="flex items-center gap-2 text-[10px] font-black uppercase tracking-wider text-zinc-300 hover:text-emerald-400 transition-all"
              >
                <i data-lucide="shield-check" class="w-3.5 h-3.5"></i> Validate
              </button>
              <button
                phx-click="show_bulk_reject_form"
                class="flex items-center gap-2 text-[10px] font-black uppercase tracking-wider text-zinc-300 hover:text-rose-400 transition-all"
              >
                <i data-lucide="trash-2" class="w-3.5 h-3.5"></i> Reject
              </button>
              <button
                phx-click="clear_selection"
                class="ml-3 text-[9px] font-mono text-zinc-500 hover:text-white uppercase tracking-wider"
              >
                Cancel
              </button>
            </div>
          <% end %>
        </div>

        <%!-- PRIMARY TERMINAL SHELL --%>
        <div class="max-w-7xl mx-auto relative z-10 h-full flex flex-col w-full overflow-hidden min-h-0">
          <%!-- ELITE DUAL-CLUSTER COMMAND BAR --%>
          <div class="flex-shrink-0 mb-6 flex items-center justify-between gap-4 relative z-[100]">
            <%!-- CLUSTER 1: DATA CONTROLS (Search + Refine) --%>
            <div class="control-cluster">
              <div class="relative flex items-center pl-3">
                <i data-lucide="search" class="w-3.5 h-3.5 text-zinc-500"></i>
                <form phx-change="search">
                  <input
                    type="text"
                    name="search"
                    id="ledger-search-input"
                    value={@search}
                    phx-debounce="300"
                    phx-hook="AdminSearch"
                    placeholder="Search Ledger..."
                    class="search-input py-2 px-3 text-xs font-medium text-white placeholder:text-zinc-600 focus:outline-none"
                  />
                </form>
                <div class="absolute right-2 flex items-center gap-2">
                  <span class="kbd-hint font-mono hidden md:block">⌘K</span>
                </div>
              </div>

              <div class="cluster-divider"></div>

              <div class="relative">
                <button
                  phx-click="toggle_filters"
                  class={[
                    "flex items-center gap-2 px-4 py-2 rounded-lg hover:bg-white/10 text-[10px] font-bold transition-all",
                    @filter_status == "all" && "text-zinc-400 hover:text-white",
                    @filter_status != "all" && "text-emerald-400"
                  ]}
                >
                  <i data-lucide="sliders-horizontal" class="w-3.5 h-3.5"></i>
                  <span class="uppercase tracking-widest">Refine</span>
                  <span
                    :if={@filter_status != "all"}
                    class="ml-1 w-4 h-4 rounded-full bg-emerald-400 text-black text-[8px] flex items-center justify-center font-black"
                  >
                    1
                  </span>
                </button>

                <%!-- POPUP FILTER --%>
                <div
                  id="filter-dropdown"
                  phx-click-away="close_filters"
                  class={[
                    "absolute left-0 top-[calc(100%+16px)] w-80 rounded-2xl p-6",
                    @show_filters && "open"
                  ]}
                >
                  <div class="flex justify-between items-center mb-5">
                    <h4 class="text-[10px] font-bold tracking-widest text-zinc-500 uppercase">
                      Filters
                    </h4>
                    <button
                      phx-click="filter_status"
                      phx-value-status="all"
                      class="text-[9px] font-bold text-emerald-400 hover:underline"
                    >
                      Reset
                    </button>
                  </div>
                  <div class="space-y-5">
                    <div class="space-y-2">
                      <label class="text-[10px] font-bold text-zinc-400 uppercase">
                        Verification Status
                      </label>
                      <div class="grid grid-cols-2 gap-2">
                        <%= for status <- @statuses do %>
                          <button
                            phx-click="filter_status"
                            phx-value-status={status}
                            class={[
                              "py-2 rounded-lg border text-[10px] transition-all",
                              @filter_status == status &&
                                "bg-emerald-400/20 border-emerald-400/50 text-emerald-400",
                              @filter_status != status &&
                                "border-white/10 text-zinc-400 hover:bg-white/5"
                            ]}
                          >
                            {String.replace(status, "_", " ")}
                          </button>
                        <% end %>
                      </div>
                    </div>
                  </div>
                </div>
              </div>
            </div>

            <%!-- CLUSTER 2: WORKSPACE UTILITIES (View + Export) --%>
            <div class="control-cluster">
              <div class="flex items-center gap-1 p-1">
                <button
                  phx-click="set_view_mode"
                  phx-value-mode="list"
                  class={[
                    "view-btn p-2 rounded-lg transition-all",
                    @view_mode == "list" && "text-emerald-400 bg-emerald-400/15",
                    @view_mode != "list" && "text-zinc-500 hover:text-white"
                  ]}
                >
                  <i data-lucide="list" class="w-3.5 h-3.5"></i>
                </button>
                <button
                  phx-click="set_view_mode"
                  phx-value-mode="grid"
                  class={[
                    "view-btn p-2 rounded-lg transition-all",
                    @view_mode == "grid" && "text-emerald-400 bg-emerald-400/15",
                    @view_mode != "grid" && "text-zinc-500 hover:text-white"
                  ]}
                >
                  <i data-lucide="grid-3x3" class="w-3.5 h-3.5"></i>
                </button>
              </div>

              <div class="cluster-divider"></div>

              <button class="flex items-center gap-2 px-4 py-2 rounded-lg hover:bg-white/5 text-[10px] font-bold text-zinc-400 hover:text-white transition-all">
                <i data-lucide="download" class="w-3.5 h-3.5"></i>
                <span class="uppercase tracking-widest hidden md:inline">Export</span>
              </button>
            </div>
          </div>

          <%!-- PRIMARY LEDGER CONTAINER (List View) --%>
          <div
            id="terminal-ledger"
            phx-hook="AdminLedger"
            data-animate-rows="true"
            class={[
              "flex-1 flex flex-col min-h-0 w-full",
              @view_mode != "list" && "hidden"
            ]}
          >
            <div class="elite-border rounded-3xl bg-[#050508]/60 backdrop-blur-2xl overflow-hidden flex-1 flex flex-col min-h-0 border border-white/5 shadow-2xl">
              <div class="overflow-auto flex-1 custom-scrollbar">
                <table class="w-full text-left border-collapse ledger-table">
                  <thead>
                    <tr class="border-b border-white/10">
                      <th class="pl-8 pr-4 py-5 w-12">
                        <input
                          type="checkbox"
                          phx-click="toggle_select_all"
                          checked={
                            @current_page_ids != [] and
                              MapSet.size(@selected_ids) == length(@current_page_ids)
                          }
                          class="custom-checkbox"
                        />
                      </th>
                      <th class="px-6 py-5 tech-label text-zinc-400 w-12">#</th>
                      <th class="px-6 py-5 tech-label text-zinc-400">Applicant / Entity</th>
                      <th class="px-6 py-5 tech-label text-zinc-400 text-right">Volume (USD)</th>
                      <th class="px-6 py-5 tech-label text-zinc-400 text-center">Status</th>
                      <th class="px-6 py-5 tech-label text-zinc-400 text-center">Confidence</th>
                      <th class="px-6 py-5 tech-label text-zinc-400 text-center">Submitted</th>
                      <th class="px-6 py-5 tech-label text-zinc-400 text-right">Action</th>
                    </tr>
                  </thead>
                  <tbody id="requests" phx-update="stream">
                    <%= for {id, request} <- @streams.requests do %>
                      <tr id={id} class="ledger-row group relative">
                        <%!-- Elite Grid Guides --%>
                        <div class="grid-guide-v left-8"></div>
                        <div class="grid-guide-v left-[calc(8rem+48px)]"></div>
                        <div class="grid-guide-h top-0"></div>
                        <div class="grid-guide-h bottom-0"></div>

                        <td class="pl-8 pr-4 py-5">
                          <input
                            type="checkbox"
                            class="custom-checkbox"
                            phx-click="toggle_select"
                            phx-value-id={request.id}
                            checked={MapSet.member?(@selected_ids, request.id)}
                          />
                        </td>
                        <td class="px-6 py-5"><span class="row-num text-xs text-zinc-500"></span></td>
                        <td class="px-6 py-5">
                          <div class="flex flex-col">
                            <span class="text-sm font-bold text-white tracking-tight">
                              {request.name}
                            </span>
                            <span class="text-[11px] font-mono text-zinc-400 mt-0.5">
                              {request.email}
                            </span>
                          </div>
                        </td>
                        <td class="px-6 py-5 text-right">
                          <span class="text-xs font-mono font-bold text-white">
                            {format_volume(request.treasury_volume)}
                          </span>
                        </td>
                        <td class="px-6 py-5 text-center">
                          <.status_pill status={request.status} />
                        </td>
                        <td class="px-6 py-5 text-center">
                          <% score = confidence_score(request) %>
                          <div class="flex items-center justify-center gap-2">
                            <div class="w-12 h-1 bg-white/10 rounded-full overflow-hidden">
                              <div
                                class={[
                                  "h-full rounded-full",
                                  score >= 80 && "bg-emerald-400",
                                  score >= 50 && score < 80 && "bg-amber-400",
                                  score < 50 && "bg-rose-400"
                                ]}
                                style={"width: #{score}%"}
                              />
                            </div>
                            <span class="text-[10px] font-mono text-zinc-400">
                              {score}%
                            </span>
                          </div>
                        </td>
                        <td class="px-6 py-5 text-center">
                          <p class="font-mono text-[11px] text-zinc-300">
                            {Calendar.strftime(request.created_at, "%b %d")}
                          </p>
                          <p class="font-mono text-[10px] text-zinc-500 mt-0.5">
                            {Date.diff(Date.utc_today(), DateTime.to_date(request.created_at))}d ago
                          </p>
                        </td>
                        <td class="px-6 py-5 text-right">
                          <button
                            phx-click="open_drawer"
                            phx-value-id={request.id}
                            class="edit-btn inline-flex items-center justify-center p-1.5 rounded-lg hover:bg-emerald-400/10 text-zinc-500 hover:text-emerald-400 transition-all"
                          >
                            <i data-lucide="pen-square" class="w-4 h-4"></i>
                          </button>
                        </td>
                      </tr>
                    <% end %>
                  </tbody>
                </table>
                <div :if={@total_count == 0} class="flex flex-col items-center justify-center py-24">
                  <.icon
                    name="hero-clipboard-document-check"
                    class="size-12 text-zinc-800 mb-4 opacity-50"
                  />
                  <p class="text-zinc-500 font-mono text-sm tracking-tight">
                    No access requests registered yet.
                  </p>
                  <p class="text-zinc-800 text-[11px] font-mono uppercase tracking-widest mt-2">
                    New institutional applications will be captured here
                  </p>
                  <button
                    phx-click="filter_status"
                    phx-value-status="all"
                    class="mt-8 px-6 py-2.5 border border-emerald-400/30 text-emerald-400 text-[10px] font-mono uppercase tracking-[0.2em] hover:bg-emerald-400/10 transition-all rounded-sm"
                  >
                    Reset Registry Cache
                  </button>
                </div>
              </div>
              <.ledger_pagination
                page={@page}
                per_page={@per_page}
                total_count={@total_count}
                total_pages={@total_pages}
                validated_count={@validated_count}
              />
            </div>
          </div>

          <%!-- CONTENT VIEWPORT (Grid View) --%>
          <div
            id="grid-container"
            class={[
              "flex-1 flex flex-col min-h-0 w-full",
              @view_mode != "grid" && "hidden"
            ]}
          >
            <div class="elite-border rounded-3xl bg-[#050508]/60 backdrop-blur-2xl overflow-hidden flex-1 flex flex-col min-h-0 border border-white/5 shadow-2xl">
              <div class="overflow-auto flex-1 custom-scrollbar p-8">
                <div
                  id="grid-items"
                  phx-update="stream"
                  class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4 gap-6"
                >
                  <%= for {id, request} <- @streams.requests do %>
                    <div
                      id={"grid-#{id}"}
                      phx-click="open_drawer"
                      phx-value-id={request.id}
                      class="grid-card relative rounded-2xl p-6 flex flex-col gap-5 h-full"
                    >
                      <div class="absolute top-4 left-4" phx-click-stop="">
                        <input
                          type="checkbox"
                          phx-click="toggle_select"
                          phx-value-id={request.id}
                          checked={MapSet.member?(@selected_ids, request.id)}
                          class="custom-checkbox"
                        />
                      </div>
                      <div class="flex justify-end">
                        <.status_pill status={request.status} />
                      </div>
                      <div class="mt-2">
                        <span class="text-[10px] font-mono text-zinc-500 uppercase tracking-widest block mb-1">
                          Institutional Entity
                        </span>
                        <p class="text-[11px] font-mono font-bold text-zinc-200 truncate">
                          {request.organization}
                        </p>
                      </div>

                      <div class="flex justify-between items-end mt-2 pt-4 border-t border-white/5">
                        <div>
                          <span class="text-[10px] font-mono text-zinc-500 uppercase tracking-widest block mb-1">
                            Submission Date
                          </span>
                          <p class="text-[11px] font-mono text-zinc-300">
                            {Calendar.strftime(request.created_at, "%Y-%m-%d %H:%M")}
                          </p>
                        </div>
                        <div class="text-right">
                          <span class="text-[10px] font-mono text-zinc-500 uppercase tracking-widest block mb-1">
                            Ref. Hash
                          </span>
                          <p class="text-[11px] font-mono text-zinc-400">
                            ID: {String.slice(request.id, 0, 8)}...
                          </p>
                        </div>
                      </div>
                      <button
                        phx-click="open_drawer"
                        phx-value-id={request.id}
                        class="mt-2 w-full py-2.5 rounded-xl bg-white/5 hover:bg-emerald-400/10 hover:text-emerald-400 text-[9px] font-bold uppercase tracking-wider transition-all"
                      >
                        Audit Details
                      </button>
                    </div>
                  <% end %>
                </div>
              </div>
              <.ledger_pagination
                page={@page}
                per_page={@per_page}
                total_count={@total_count}
                total_pages={@total_pages}
                validated_count={@validated_count}
              />
            </div>
          </div>
        </div>
      </div>

      <%!-- SIDE DRAWER --%>
      <div
        id="side-drawer"
        class={[
          "side-drawer-elite fixed top-0 right-0 h-full w-full max-w-md z-[50] p-8 flex flex-col",
          @show_drawer && "open"
        ]}
      >
        <div class="flex justify-between items-center mb-10 pb-6 border-b border-white/5">
          <div class="space-y-1">
            <h3 class="text-xl font-bold tracking-tight text-white">
              Request <span class="text-emerald-400">Analysis</span>
            </h3>
            <div :if={@drawer_request} class="flex items-center gap-2">
              <span class="px-1.5 py-0.5 rounded bg-white/5 border border-white/10 text-[9px] font-mono text-zinc-500 uppercase">
                ID
              </span>
              <span class="text-[10px] font-mono text-zinc-600">
                {"0x"}{String.slice(@drawer_request.id |> to_string, 0, 8)}
              </span>
            </div>
          </div>
          <button
            phx-click="close_drawer"
            class="p-2 rounded-xl hover:bg-white/5 transition-all group"
          >
            <i data-lucide="x" class="w-5 h-5 text-zinc-500 group-hover:text-white transition"></i>
          </button>
        </div>

        <div
          :if={!@drawer_request}
          class="flex-1 flex flex-col items-center justify-center space-y-4 opacity-20"
        >
          <i data-lucide="layers" class="w-12 h-12"></i>
          <p class="text-[10px] font-bold uppercase tracking-widest">No Selection</p>
        </div>

        <div :if={@drawer_request} class="flex-1 space-y-8 overflow-y-auto pr-2 custom-scrollbar">
          <div class="grid grid-cols-1 gap-6">
            <.eq_drawer_field label="Full Name" value={@drawer_request.name} />
            <.eq_drawer_field label="Institutional Email" value={@drawer_request.email} />
            <.eq_drawer_field label="Entity Identifier" value={@drawer_request.organization} />
            <.eq_drawer_field
              label="Treasury Volume"
              value={format_volume(@drawer_request.treasury_volume)}
            />
          </div>

          <div class="rounded-2xl border border-white/5 bg-white/[0.02] p-6 space-y-5">
            <div class="flex items-center justify-between">
              <div class="flex items-center gap-2">
                <i data-lucide="shield-check" class="w-4 h-4 text-emerald-400"></i>
                <span class="text-[10px] font-bold uppercase tracking-widest text-zinc-400">
                  Protocol Metadata
                </span>
              </div>
              <.status_pill status={@drawer_request.status} />
            </div>
            <div class="grid grid-cols-2 gap-4">
              <div class="space-y-1">
                <span class="text-[9px] font-medium text-zinc-600 uppercase tracking-wider">
                  Submission Time
                </span>
                <p class="text-[11px] font-mono text-zinc-400">
                  {Calendar.strftime(@drawer_request.created_at, "%Y-%m-%d %H:%M:%S")} UTC
                </p>
              </div>
              <div class="space-y-1">
                <span class="text-[9px] font-medium text-zinc-600 uppercase tracking-wider">
                  Confidence Score
                </span>
                <div class="flex items-center gap-2">
                  <div class="w-8 h-1 rounded-full bg-white/5 overflow-hidden">
                    <div
                      class="h-full bg-emerald-400"
                      style={"width: #{confidence_score(@drawer_request)}%"}
                    >
                    </div>
                  </div>
                  <p class="text-[11px] font-mono text-emerald-400">
                    {confidence_score(@drawer_request)}%
                  </p>
                </div>
              </div>
            </div>
          </div>

          <%!-- Duplicate entity warning --%>
          <div
            :if={@duplicate_warnings != []}
            class="rounded-2xl border border-amber-400/20 bg-amber-400/[0.03] p-5 space-y-3"
          >
            <div class="flex items-center gap-2">
              <i data-lucide="alert-triangle" class="w-4 h-4 text-amber-400"></i>
              <span class="text-[10px] font-bold uppercase tracking-widest text-amber-400/80">
                Duplicate Detected
              </span>
            </div>
            <ul class="space-y-1.5">
              <%= for warning <- @duplicate_warnings do %>
                <li class="text-[10px] font-mono text-zinc-400 leading-relaxed">{warning}</li>
              <% end %>
            </ul>
          </div>

          <div
            :if={@invitation_link}
            class="rounded-2xl border border-emerald-400/20 bg-emerald-400/[0.03] p-6 space-y-4"
          >
            <div class="flex items-center gap-2">
              <i data-lucide="key" class="w-4 h-4 text-emerald-400"></i>
              <span class="text-[10px] font-bold uppercase tracking-widest text-emerald-400/80">
                Biometric Invitation
              </span>
            </div>
            <div class="p-4 bg-black/40 rounded-xl border border-white/5 group relative">
              <p class="text-[10px] font-mono text-zinc-400 break-all leading-relaxed pr-8">
                {@invitation_link}
              </p>
              <button
                phx-click={JS.dispatch("phx:copy-to-clipboard", detail: %{text: @invitation_link})}
                class="absolute right-3 top-3 p-1.5 rounded-lg hover:bg-white/10 text-zinc-500 hover:text-emerald-400 transition-all"
                title="Copy to clipboard"
              >
                <i data-lucide="copy" class="w-3.5 h-3.5"></i>
              </button>
            </div>
          </div>
        </div>

        <div class="pt-8 mt-4 border-t border-white/5 space-y-4">
          <%!-- Rejection reason display --%>
          <div
            :if={
              @drawer_request && @drawer_request.status == "rejected" &&
                @drawer_request.rejection_reason
            }
            class="p-5 rounded-2xl border border-rose-400/20 bg-rose-400/[0.03] space-y-3"
          >
            <div class="flex items-center gap-2">
              <i data-lucide="alert-circle" class="w-4 h-4 text-rose-400"></i>
              <span class="text-[10px] font-bold uppercase tracking-widest text-rose-400/80">
                Rejection Log
              </span>
            </div>
            <p class="text-[11px] font-medium text-zinc-300 leading-relaxed">
              {@drawer_request.rejection_reason}
            </p>
          </div>

          <%!-- Review & authorization actions (pending and under_review) --%>
          <%= if @drawer_request && @drawer_request.status in ["pending", "under_review"] do %>
            <%!-- Reject form --%>
            <div :if={@show_reject_form} class="space-y-4">
              <div class="space-y-2">
                <label class="text-[10px] font-bold uppercase tracking-wider text-zinc-500">
                  Reason for Rejection
                </label>
                <textarea
                  phx-change="set_reject_reason"
                  name="reason"
                  rows="3"
                  placeholder="Provide audit reason..."
                  class="w-full bg-white/[0.02] border border-rose-400/20 rounded-xl px-4 py-4 text-xs font-medium text-white placeholder:text-zinc-700 focus:outline-none focus:border-rose-400/40 resize-none transition-all"
                >{@reject_reason}</textarea>
              </div>
              <div class="flex gap-3">
                <button
                  phx-click="reject_request"
                  phx-value-id={@drawer_request.id}
                  disabled={String.trim(@reject_reason) == ""}
                  class="flex-1 py-4 bg-rose-500 text-white rounded-xl text-[10px] font-bold uppercase tracking-widest hover:bg-rose-400 transition-all disabled:opacity-30"
                >
                  Confirm Rejection
                </button>
                <button
                  phx-click="cancel_reject"
                  class="py-4 px-6 border border-white/10 text-zinc-400 rounded-xl text-[10px] font-bold uppercase tracking-widest hover:text-white transition-all"
                >
                  Cancel
                </button>
              </div>
            </div>

            <%!-- Role selection + approve/reject --%>
            <div :if={!@show_reject_form} class="space-y-4">
              <div class="space-y-2">
                <label class="text-[10px] font-bold uppercase tracking-wider text-zinc-500">
                  Provisioning Role
                </label>
                <select
                  phx-change="set_approve_role"
                  name="role"
                  class="w-full bg-white/[0.02] border border-white/10 rounded-xl px-4 py-3.5 text-xs font-medium text-white focus:outline-none focus:border-emerald-400/40 transition-all"
                >
                  <option value="">Select Target Role</option>
                  <%= for role <- Roles.all() do %>
                    <option value={role} selected={@approve_role == role}>{role}</option>
                  <% end %>
                </select>
              </div>
              <div class="flex gap-3">
                <button
                  phx-click="approve_request"
                  phx-value-id={@drawer_request.id}
                  disabled={@approve_role == ""}
                  class="flex-1 py-4 bg-emerald-400 text-black rounded-xl text-[10px] font-bold uppercase tracking-widest hover:bg-white transition-all disabled:opacity-30 shadow-lg shadow-emerald-400/10"
                >
                  Confirm Authorization
                </button>
                <button
                  phx-click="show_reject_form"
                  class="px-5 border border-rose-400/30 text-rose-400 rounded-xl text-[10px] font-bold uppercase tracking-widest hover:bg-rose-400/10 transition-all"
                  title="Reject Request"
                >
                  <i data-lucide="x-circle" class="w-5 h-5"></i>
                </button>
              </div>
            </div>
          <% end %>
        </div>
      </div>
    </Layouts.app>
    """
  end

  # ── Events ────────────────────────────────────────────────────────────────────

  @impl true
  def handle_event("filter_status", %{"status" => status}, socket) do
    {:noreply,
     socket
     |> assign(filter_status: status, page: 1, selected_ids: MapSet.new())
     |> load_requests()}
  end

  def handle_event("search", %{"search" => q}, socket) do
    {:noreply, socket |> assign(search: q, page: 1) |> load_requests()}
  end

  def handle_event("change_page_size", %{"page_size" => size}, socket) do
    {:noreply,
     socket
     |> assign(per_page: String.to_integer(size), page: 1)
     |> load_requests()}
  end

  def handle_event("toggle_select", %{"id" => id}, socket) do
    selected_ids =
      if MapSet.member?(socket.assigns.selected_ids, id) do
        MapSet.delete(socket.assigns.selected_ids, id)
      else
        MapSet.put(socket.assigns.selected_ids, id)
      end

    {:noreply,
     socket
     |> assign(selected_ids: selected_ids)
     |> load_requests()}
  end

  def handle_event("toggle_select_all", _params, socket) do
    all_ids = MapSet.new(socket.assigns.current_page_ids)

    selected_ids =
      if MapSet.equal?(socket.assigns.selected_ids, all_ids) do
        MapSet.new()
      else
        all_ids
      end

    {:noreply,
     socket
     |> assign(selected_ids: selected_ids)
     |> load_requests()}
  end

  def handle_event("clear_selection", _, socket) do
    {:noreply, assign(socket, selected_ids: MapSet.new())}
  end

  def handle_event("paginate", %{"page" => page}, socket) do
    {:noreply, socket |> assign(page: String.to_integer(page)) |> load_requests()}
  end

  def handle_event("open_drawer", %{"id" => id}, socket) do
    request = Repo.get!(AccessRequest, id)

    invitation_link =
      if request.status == "approved" && request.provisioned_user_id do
        token = BiometricInvitation.generate_token(request.provisioned_user_id)
        BiometricInvitation.magic_link(token)
      end

    default_role = Roles.all() |> List.first() || ""

    {:noreply,
     assign(socket,
       show_drawer: true,
       drawer_request: request,
       approve_role: default_role,
       show_reject_form: false,
       reject_reason: "",
       invitation_link: invitation_link,
       duplicate_warnings: find_duplicate_warnings(request)
     )}
  end

  def handle_event("toggle_filters", _, socket) do
    {:noreply, assign(socket, show_filters: !socket.assigns.show_filters)}
  end

  def handle_event("close_filters", _, socket) do
    {:noreply, assign(socket, show_filters: false)}
  end

  def handle_event("close_drawer", _, socket) do
    {:noreply,
     assign(socket,
       show_drawer: false,
       drawer_request: nil,
       approve_role: "",
       show_reject_form: false,
       reject_reason: "",
       invitation_link: nil,
       duplicate_warnings: []
     )}
  end

  def handle_event("show_reject_form", _, socket) do
    {:noreply, assign(socket, show_reject_form: true, reject_reason: "")}
  end

  def handle_event("cancel_reject", _, socket) do
    {:noreply, assign(socket, show_reject_form: false, reject_reason: "")}
  end

  def handle_event("set_reject_reason", %{"reason" => reason}, socket) do
    {:noreply, assign(socket, reject_reason: reason)}
  end

  def handle_event("reject_request", %{"id" => id}, socket) do
    reason = String.trim(socket.assigns.reject_reason)

    if reason == "" do
      {:noreply, put_flash(socket, :error, "Please provide a rejection reason.")}
    else
      require OpenTelemetry.Tracer

      if socket.assigns.drawer_request && socket.assigns.drawer_request.status == "pending" do
        review_cmd = %ReviewAccessRequest{
          request_id: id,
          reviewed_by: socket.assigns.current_user.id
        }

        tracing_metadata = Tracing.inject_context(%{})

        OpenTelemetry.Tracer.with_span "Admin.ReviewAccessRequest" do
          App.dispatch(review_cmd,
            metadata: Map.put(tracing_metadata, "idempotency_key", "#{id}:review")
          )
        end
      end

      command = %RejectAccessRequest{
        request_id: id,
        rejected_by: socket.assigns.current_user.id,
        reason: reason
      }

      tracing_metadata = Tracing.inject_context(%{})

      OpenTelemetry.Tracer.with_span "Admin.RejectAccessRequest" do
        case App.dispatch(command,
               metadata: Map.put(tracing_metadata, "idempotency_key", "#{id}:reject")
             ) do
          :ok ->
            {:noreply,
             socket
             |> assign(show_reject_form: false, reject_reason: "")
             |> load_requests()
             |> refresh_drawer(id)
             |> push_event("toast:show:success", %{message: "Request rejected", duration: 4_000})}

          {:error, reason_err} ->
            {:noreply, put_flash(socket, :error, "Failed to reject: #{inspect(reason_err)}")}
        end
      end
    end
  end

  def handle_event("set_approve_role", %{"role" => role}, socket) do
    {:noreply, assign(socket, approve_role: role)}
  end

  def handle_event("set_view_mode", %{"mode" => mode}, socket) do
    {:noreply, assign(socket, view_mode: mode)}
  end

  def handle_event("transition_status", %{"id" => id, "to" => to_status}, socket) do
    require OpenTelemetry.Tracer

    command =
      case to_status do
        "under_review" ->
          %ReviewAccessRequest{request_id: id, reviewed_by: socket.assigns.current_user.id}

        "archived" ->
          %ArchiveAccessRequest{request_id: id, archived_by: socket.assigns.current_user.id}

        _ ->
          nil
      end

    if command do
      tracing_metadata = Tracing.inject_context(%{})

      OpenTelemetry.Tracer.with_span "Admin.TransitionAccessRequest" do
        case App.dispatch(command,
               metadata: Map.put(tracing_metadata, "idempotency_key", "#{id}:#{to_status}")
             ) do
          :ok ->
            {:noreply,
             socket
             |> load_requests()
             |> refresh_drawer(id)
             |> push_event("toast:show:success", %{
               message: "Request marked as #{String.replace(to_status, "_", " ")}",
               duration: 4_000
             })}

          {:error, reason} ->
            {:noreply, put_flash(socket, :error, "Transition failed: #{inspect(reason)}")}
        end
      end
    else
      {:noreply, put_flash(socket, :error, "Invalid status transition.")}
    end
  end

  def handle_event("approve_request", %{"id" => id}, socket) do
    role = socket.assigns.approve_role

    if role == "" do
      {:noreply, put_flash(socket, :error, "Please select a role before approving.")}
    else
      require OpenTelemetry.Tracer
      require Logger

      if socket.assigns.drawer_request && socket.assigns.drawer_request.status == "pending" do
        review_cmd = %ReviewAccessRequest{
          request_id: id,
          reviewed_by: socket.assigns.current_user.id
        }

        tracing_metadata = Tracing.inject_context(%{})

        OpenTelemetry.Tracer.with_span "Admin.ReviewAccessRequest" do
          App.dispatch(review_cmd,
            metadata: Map.put(tracing_metadata, "idempotency_key", "#{id}:review")
          )
        end
      end

      user_id = Uniq.UUID.uuid7()
      org_id = Uniq.UUID.uuid7()

      command = %ApproveAccessRequest{
        request_id: id,
        approved_by: socket.assigns.current_user.id,
        role: role,
        provisioned_user_id: user_id,
        provisioned_org_id: org_id
      }

      OpenTelemetry.Tracer.with_span "Admin.ApproveAccessRequest" do
        tracing_metadata = Tracing.inject_context(%{})

        case App.dispatch(command,
               metadata: Map.put(tracing_metadata, "idempotency_key", "#{id}:approve")
             ) do
          :ok ->
            token = BiometricInvitation.generate_token(user_id)
            link = BiometricInvitation.magic_link(token)

            Process.send_after(self(), :refresh_after_approval, 1_000)

            {:noreply,
             socket
             |> assign(
               approve_role: "",
               invitation_link: link,
               drawer_request:
                 socket.assigns.drawer_request &&
                   %{socket.assigns.drawer_request | status: "approved"}
             )
             |> push_event("toast:show:success", %{
               message: "Access approved — invitation link generated",
               duration: 5_000
             })}

          {:error, reason} ->
            Logger.error("[Admin] Approval dispatch failed: #{inspect(reason)}")
            {:noreply, put_flash(socket, :error, "Approval failed: #{inspect(reason)}")}
        end
      end
    end
  end

  def handle_event("bulk_under_review", _, socket) do
    require OpenTelemetry.Tracer
    tracing_metadata = Tracing.inject_context(%{})

    socket.assigns.selected_ids
    |> MapSet.to_list()
    |> Enum.each(fn id ->
      command = %ReviewAccessRequest{
        request_id: id,
        reviewed_by: socket.assigns.current_user.id
      }

      OpenTelemetry.Tracer.with_span "Admin.BulkReview" do
        App.dispatch(command,
          metadata: Map.put(tracing_metadata, "idempotency_key", "#{id}:review")
        )
      end
    end)

    {:noreply, socket |> assign(selected_ids: MapSet.new()) |> load_requests()}
  end

  def handle_event("show_bulk_reject_form", _, socket) do
    {:noreply, assign(socket, show_bulk_reject_form: true, bulk_reject_reason: "")}
  end

  def handle_event("cancel_bulk_reject", _, socket) do
    {:noreply, assign(socket, show_bulk_reject_form: false, bulk_reject_reason: "")}
  end

  def handle_event("set_bulk_reject_reason", %{"bulk_reason" => reason}, socket) do
    {:noreply, assign(socket, bulk_reject_reason: reason)}
  end

  def handle_event("bulk_reject", _, socket) do
    reason = String.trim(socket.assigns.bulk_reject_reason)

    if reason == "" do
      {:noreply, put_flash(socket, :error, "Please provide an audit reason for batch rejection.")}
    else
      require OpenTelemetry.Tracer
      tracing_metadata = Tracing.inject_context(%{})

      socket.assigns.selected_ids
      |> MapSet.to_list()
      |> Enum.each(fn id ->
        command = %RejectAccessRequest{
          request_id: id,
          rejected_by: socket.assigns.current_user.id,
          reason: reason
        }

        OpenTelemetry.Tracer.with_span "Admin.BulkReject" do
          App.dispatch(command,
            metadata: Map.put(tracing_metadata, "idempotency_key", "#{id}:reject")
          )
        end
      end)

      {:noreply,
       socket
       |> assign(selected_ids: MapSet.new(), show_bulk_reject_form: false, bulk_reject_reason: "")
       |> load_requests()}
    end
  end

  # ── Info Handlers ─────────────────────────────────────────────────────────────

  @impl true
  def handle_info(:refresh_after_approval, socket) do
    {:noreply, socket |> load_requests() |> refresh_drawer_if_open()}
  end

  # ── Private ───────────────────────────────────────────────────────────────────

  defp refresh_drawer_if_open(socket) do
    case socket.assigns.drawer_request do
      nil -> socket
      req -> refresh_drawer(socket, req.id)
    end
  end

  defp load_requests(socket) do
    %{page: page, filter_status: filter_status, search: search} = socket.assigns

    base = from(r in AccessRequest, order_by: [desc: r.created_at])

    filtered =
      if filter_status != "all" do
        from(r in base, where: r.status == ^filter_status)
      else
        base
      end

    searched =
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

    total = Repo.aggregate(searched, :count, :id)
    total_pages = max(1, ceil(total / socket.assigns.per_page))

    validated_count =
      searched
      |> where([r], r.status == "approved")
      |> Repo.aggregate(:count, :id)

    requests =
      searched
      |> limit(^socket.assigns.per_page)
      |> offset(^((page - 1) * socket.assigns.per_page))
      |> Repo.all()

    socket
    |> assign(
      total_count: total,
      total_pages: total_pages,
      validated_count: validated_count,
      current_page_ids: Enum.map(requests, & &1.id)
    )
    |> stream(:requests, requests, reset: true)
  end

  defp refresh_drawer(socket, id) do
    if socket.assigns.drawer_request && socket.assigns.drawer_request.id == id do
      case Repo.get(AccessRequest, id) do
        nil -> assign(socket, drawer_request: nil, show_drawer: false)
        updated -> assign(socket, drawer_request: updated)
      end
    else
      socket
    end
  end

  defp find_duplicate_warnings(request) do
    email_match =
      Repo.one(
        from(r in AccessRequest,
          where: r.email == ^request.email and r.status == "approved" and r.id != ^request.id,
          select: r.name,
          limit: 1
        )
      )

    org_match =
      Repo.one(
        from(r in AccessRequest,
          where:
            r.organization == ^request.organization and r.status == "approved" and
              r.id != ^request.id,
          select: r.name,
          limit: 1
        )
      )

    []
    |> then(fn w ->
      if email_match,
        do: ["Email #{request.email} already approved under account \"#{email_match}\"" | w],
        else: w
    end)
    |> then(fn w ->
      if org_match,
        do: [
          "Organization \"#{request.organization}\" already approved under account \"#{org_match}\""
          | w
        ],
        else: w
    end)
  end

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

  defp message_score(msg) when is_binary(msg) do
    if String.trim(msg) != "", do: 15, else: 0
  end

  defp message_score(_), do: 0

  defp email_score(email), do: if(work_email?(email), do: 15, else: 0)

  defp org_score(org) when is_binary(org) do
    if String.length(org) > 5, do: 10, else: 0
  end

  defp org_score(_), do: 0

  @free_domains ~w(gmail.com yahoo.com hotmail.com outlook.com icloud.com)

  defp work_email?(email) do
    case String.split(email, "@") do
      [_, domain] -> domain not in @free_domains
      _ -> false
    end
  end

  defp format_volume("lt_10m"), do: "< $10M"
  defp format_volume("10m_100m"), do: "$10M – $100M"
  defp format_volume("100m_500m"), do: "$100M – $500M"
  defp format_volume("500m_1b"), do: "$500M – $1B"
  defp format_volume("gt_1b"), do: "> $1B"
  defp format_volume(v), do: v

  defp ledger_pagination(assigns) do
    ~H"""
    <div class="flex-shrink-0 px-8 py-5 border-t border-white/10 bg-black/30 flex flex-wrap items-center justify-between gap-4">
      <div class="flex items-center gap-5">
        <span class="text-[9px] font-mono text-zinc-500 uppercase tracking-wider">
          Range:
          <span class="text-white">
            {(@page - 1) * @per_page + 1} - {min(@page * @per_page, @total_count)}
          </span>
        </span>
        <div class="h-3 w-px bg-white/10"></div>
        <span class="text-[9px] font-mono text-zinc-500 uppercase tracking-wider">
          Total: <span class="text-white">{@total_count}</span>
        </span>
        <div class="h-3 w-px bg-white/10 hidden sm:block"></div>
        <span class="text-[9px] font-mono text-zinc-500 uppercase tracking-wider hidden sm:inline">
          Validated: <span class="text-emerald-400">{@validated_count}</span>
        </span>
      </div>
      <div class="flex items-center gap-3">
        <form phx-change="change_page_size">
          <select
            name="page_size"
            class="bg-black/40 border border-white/10 rounded-lg px-3 py-2 text-[9px] font-mono text-white focus:outline-none focus:border-emerald-400/40"
          >
            <%= for size <- [10, 25, 50, 100] do %>
              <option value={size} selected={@per_page == size}>{size} / page</option>
            <% end %>
          </select>
        </form>

        <button
          phx-click="paginate"
          phx-value-page={@page - 1}
          disabled={@page == 1}
          class="flex items-center gap-2 px-5 py-2 rounded-full border border-white/10 text-[9px] font-black uppercase tracking-wider text-zinc-400 hover:text-white hover:border-emerald-400/50 transition-all disabled:opacity-30"
        >
          <i data-lucide="chevron-left" class="w-3 h-3"></i> Prev
        </button>

        <span class="text-[9px] font-mono text-zinc-500">
          Page {@page} of {@total_pages}
        </span>

        <button
          phx-click="paginate"
          phx-value-page={@page + 1}
          disabled={@page >= @total_pages}
          class="flex items-center gap-2 px-5 py-2 rounded-full border border-white/10 text-[9px] font-black uppercase tracking-wider text-zinc-400 hover:text-white hover:border-emerald-400/50 transition-all disabled:opacity-30"
        >
          Next <i data-lucide="chevron-right" class="w-3 h-3"></i>
        </button>
      </div>
    </div>
    """
  end
end
