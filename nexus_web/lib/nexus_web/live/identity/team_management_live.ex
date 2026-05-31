defmodule NexusWeb.Identity.TeamManagementLive do
  use NexusWeb, :live_view

  alias Nexus.Identity.Commands.{DeactivateUser, UpdateUserRole}
  alias Nexus.Identity.Queries.ListOrgMembers
  alias NexusShared.Identity.Roles
  require Logger

  @impl true
  def mount(_params, _session, socket) do
    user = socket.assigns.current_user

    if user && can_manage_team?(user) do
      members = ListOrgMembers.execute(user.org_id)
      admin_count = Enum.count(members, &(&1.role in ~w(admin org_admin)))

      {:ok,
       socket
       |> assign(:page_title, "Team Management")
       |> assign(:members, members)
       |> assign(:total_members, length(members))
       |> assign(:admin_count, admin_count)
       |> assign(:confirm_deactivate, nil)
       |> assign(:role_change, nil)
       |> assign(:selected_role, nil)
       |> assign(:action_error, nil)
       |> assign(:search_query, "")
       |> assign(:page, 1)
       |> assign(:per_page, 10)}
    else
      {:ok,
       socket
       |> put_flash(:error, "You do not have permission to manage team members.")
       |> redirect(to: ~p"/vaults")}
    end
  end

  @impl true
  def render(assigns) do
    filtered = filter_members(assigns.members, assigns.search_query)
    total_count = length(filtered)
    total_pages = max(1, ceil(total_count / assigns.per_page))
    paginated = Enum.slice(filtered, (assigns.page - 1) * assigns.per_page, assigns.per_page)

    assigns =
      assigns
      |> assign(:total_count, total_count)
      |> assign(:total_pages, total_pages)
      |> assign(:paginated_members, paginated)

    ~H"""
    <Layouts.app
      flash={@flash}
      current_user={@current_user}
      page_title={@page_title}
      breadcrumb_section="Team"
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
                  placeholder="SEARCH ROSTER..."
                  value={@search_query}
                  phx-input="search"
                  phx-debounce="300"
                  class="search-input py-2.5 px-4 text-[10px] font-mono font-bold text-white placeholder:text-zinc-700 focus:outline-none uppercase tracking-widest"
                />
              </div>
            </.eq_control_cluster>

            <.eq_control_cluster>
              <.eq_button navigate={~p"/team/invite"} variant="primary" class="!px-6 !py-3" arrow>
                Invite Member
              </.eq_button>
            </.eq_control_cluster>
          </.eq_control_bar>

          <%!-- HUD Stats Ribbon --%>
          <div class="grid grid-cols-4 gap-6">
            <.hud_metric_card
              label="Total Personnel"
              value={@total_members}
              color="emerald"
              status="VERIFIED"
            />
            <.hud_metric_card
              label="Active Admins"
              value={@admin_count}
              color="sky"
              status="PRIVILEGED"
            />
            <.hud_metric_card
              label="Invite Slots"
              value="UNLIMITED"
              color="zinc"
              status="ELITE"
            />
            <.hud_metric_card
              label="Audit Integrity"
              value="100%"
              color="emerald"
              status="IMMUTABLE"
            />
          </div>

          <%!-- Action error --%>
          <%= if @action_error do %>
            <div class="p-4 bg-rose-400/10 border border-rose-400/20 rounded-xl text-[10px] font-mono text-rose-400 uppercase tracking-widest flex items-center gap-3">
              <.icon name="hero-exclamation-circle-mini" class="w-4 h-4" />
              {@action_error}
            </div>
          <% end %>

          <%!-- Confirm deactivation modal --%>
          <%= if @confirm_deactivate do %>
            <div class="fixed inset-0 z-[100] flex items-center justify-center bg-black/80 backdrop-blur-md">
              <.prestige_card class="w-full max-w-sm p-10 border-rose-500/20 shadow-2xl">
                <div class="mb-8">
                  <div class="w-14 h-14 rounded-2xl bg-rose-400/10 border border-rose-400/20 flex items-center justify-center mb-6 shadow-[0_0_20px_rgba(244,63,94,0.1)]">
                    <.icon name="hero-exclamation-triangle-mini" class="w-7 h-7 text-rose-400" />
                  </div>
                  <h2 class="text-xl font-black text-white mb-2 uppercase tracking-tight">
                    Deactivate Member
                  </h2>
                  <p class="text-[10px] font-mono text-zinc-500 leading-relaxed uppercase tracking-widest">
                    This will immediately revoke access for <span class="text-white">{@confirm_deactivate.name}</span>.
                    This action is logged in the immutable audit trail.
                  </p>
                </div>
                <div class="flex gap-4">
                  <.eq_button phx-click="cancel_deactivate" variant="outline" class="flex-1">
                    Cancel
                  </.eq_button>
                  <.eq_button
                    phx-click="confirm_deactivate"
                    phx-value-user_id={@confirm_deactivate.id}
                    variant="danger"
                    class="flex-1"
                  >
                    Deactivate
                  </.eq_button>
                </div>
              </.prestige_card>
            </div>
          <% end %>

          <%!-- Role change modal --%>
          <%= if @role_change do %>
            <div class="fixed inset-0 z-[100] flex items-center justify-center bg-black/80 backdrop-blur-md">
              <.prestige_card class="w-full max-w-md p-10 border-emerald-400/20 shadow-2xl">
                <div class="mb-8">
                  <div class="w-14 h-14 rounded-2xl bg-emerald-400/10 border border-emerald-400/20 flex items-center justify-center mb-6 shadow-[0_0_20px_rgba(52,211,153,0.1)]">
                    <.icon name="hero-shield-check-mini" class="w-7 h-7 text-emerald-400" />
                  </div>
                  <h2 class="text-xl font-black text-white mb-2 uppercase tracking-tight">
                    Modify Role
                  </h2>
                  <p class="text-[10px] font-mono text-zinc-500 uppercase tracking-widest">
                    Updating privileges for <span class="text-white">{@role_change.name}</span>
                  </p>
                </div>

                <.eq_form for={%{}} as={:role_update} phx-submit="confirm_role_change">
                  <input type="hidden" name="user_id" value={@role_change.id} />
                  <.eq_select
                    name="new_role"
                    label="Assigned Authorization Level"
                    options={assignable_roles()}
                    value={@role_change.role}
                  />
                  <:actions>
                    <div class="flex gap-4 mt-8">
                      <.eq_button
                        type="button"
                        phx-click="cancel_role_change"
                        variant="outline"
                        class="flex-1"
                      >
                        Cancel
                      </.eq_button>
                      <.eq_button type="submit" variant="primary" class="flex-1">
                        Update Role
                      </.eq_button>
                    </div>
                  </:actions>
                </.eq_form>
              </.prestige_card>
            </div>
          <% end %>

          <%!-- Member table --%>
          <div class="space-y-4 flex flex-col min-h-0">
            <div class="flex items-center gap-4 px-2">
              <h3 class="text-[10px] font-black uppercase tracking-[0.4em] text-white/30">
                Identity · Roster
              </h3>
              <div class="h-px flex-1 bg-white/[0.03]"></div>
            </div>

            <div class="elite-border rounded-3xl bg-[#050508]/60 backdrop-blur-2xl overflow-hidden flex-1 flex flex-col min-h-0 border border-white/5 shadow-2xl">
              <div class="overflow-auto flex-1 custom-scrollbar">
                <%= if @total_count == 0 do %>
                  <.ledger_empty_state
                    title="No matching personnel found"
                    subtitle="Try adjusting your search criteria"
                    action_label={if @search_query != "", do: "Clear Search", else: nil}
                    action_event={if @search_query != "", do: "clear_search", else: nil}
                  />
                <% else %>
                  <.ledger_table id="members-roster" rows={@paginated_members}>
                    <:col :let={member} label="Personnel Identity">
                      <div class="flex items-center gap-6 relative">
                        <div class="grid-guide-v -left-8"></div>
                        <div class="grid-guide-h top-0"></div>
                        <div class="grid-guide-h bottom-0"></div>
                        <div class="w-10 h-10 rounded-xl bg-white/5 border border-white/10 flex items-center justify-center text-[11px] font-mono font-black text-emerald-400 shadow-inner">
                          {member.name |> String.first() |> String.upcase()}
                        </div>
                        <div>
                          <p class="text-sm font-black text-white tracking-tight">{member.name}</p>
                          <p class="text-[10px] font-mono text-zinc-500 uppercase tracking-widest mt-1">
                            {member.email}
                          </p>
                        </div>
                      </div>
                    </:col>

                    <:col :let={member} label="Authorization Level">
                      <div class="flex items-center gap-3">
                        <.icon
                          name={
                            if(member.role in ~w(admin org_admin),
                              do: "hero-shield-check-mini",
                              else: "hero-user-mini"
                            )
                          }
                          class={"w-4 h-4 #{if member.role in ~w(admin org_admin), do: "text-emerald-400", else: "text-zinc-600"}"}
                        />
                        <span class={[
                          "text-[10px] font-mono font-bold uppercase tracking-widest",
                          member.role in ~w(admin org_admin) && "text-white",
                          member.role not in ~w(admin org_admin) && "text-zinc-500"
                        ]}>
                          {String.replace(member.role, "_", " ")}
                        </span>
                      </div>
                    </:col>

                    <:col :let={_member} label="Status">
                      <.eq_badge status="active" />
                    </:col>

                    <:action :let={member}>
                      <div class="flex items-center gap-2">
                        <button
                          phx-click="open_role_change"
                          phx-value-user_id={member.id}
                          class="p-2.5 rounded-lg bg-white/5 text-zinc-500 hover:text-emerald-400 hover:bg-emerald-400/10 transition-all group"
                          title="Modify Role"
                        >
                          <.icon
                            name="hero-cog-6-tooth-mini"
                            class="w-4 h-4 group-hover:rotate-90 transition-transform duration-500"
                          />
                        </button>
                        <button
                          :if={member.id != @current_user.id}
                          phx-click="request_deactivate"
                          phx-value-user_id={member.id}
                          class="p-2.5 rounded-lg bg-white/5 text-zinc-500 hover:text-rose-400 hover:bg-rose-400/10 transition-all group"
                          title="Deactivate Member"
                        >
                          <.icon name="hero-user-minus-mini" class="w-4 h-4" />
                        </button>
                      </div>
                    </:action>
                  </.ledger_table>
                <% end %>
              </div>
              <.ledger_pagination
                page={@page}
                per_page={@per_page}
                total_count={@total_count}
                total_pages={@total_pages}
                extra_label="Admins"
                extra_count={@admin_count}
              />
            </div>
          </div>

          <%!-- Footer HUD --%>
          <div class="flex justify-between items-center pt-8 border-t border-white/[0.02]">
            <div class="flex items-center gap-6">
              <div class="flex flex-col">
                <span class="text-[8px] font-mono font-black text-zinc-600 uppercase tracking-widest mb-1">
                  System Roster Count
                </span>
                <span class="text-xs font-mono font-bold text-zinc-400">{@total_count} ENTITIES</span>
              </div>
              <div class="w-px h-8 bg-white/5"></div>
              <div class="flex flex-col">
                <span class="text-[8px] font-mono font-black text-zinc-600 uppercase tracking-widest mb-1">
                  Audit Protocol
                </span>
                <span class="text-xs font-mono font-bold text-emerald-500/50">
                  NON-REPUDIATION ACTIVE
                </span>
              </div>
            </div>
            <.link
              navigate={~p"/vaults"}
              class="text-[9px] font-mono font-black text-zinc-500 hover:text-white transition-all uppercase tracking-[0.2em] flex items-center gap-2 group"
            >
              <.icon
                name="hero-arrow-left-mini"
                class="w-4 h-4 group-hover:-translate-x-1 transition-transform"
              /> Return to System Hub
            </.link>
          </div>
        </div>
      </div>
    </Layouts.app>
    """
  end

  # ── Events ──────────────────────────────────────────────────────────────────

  @impl true
  def handle_event("search", %{"value" => query}, socket) do
    {:noreply, assign(socket, search_query: query, page: 1)}
  end

  @impl true
  def handle_event("clear_search", _params, socket) do
    {:noreply, assign(socket, search_query: "", page: 1)}
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

  @impl true
  def handle_event("request_deactivate", %{"user_id" => user_id}, socket) do
    member = Enum.find(socket.assigns.members, &(&1.id == user_id))
    {:noreply, assign(socket, confirm_deactivate: member, action_error: nil)}
  end

  @impl true
  def handle_event("cancel_deactivate", _params, socket) do
    {:noreply, assign(socket, confirm_deactivate: nil)}
  end

  @impl true
  def handle_event("confirm_deactivate", %{"user_id" => user_id}, socket) do
    user = socket.assigns.current_user

    command = %DeactivateUser{
      user_id: user_id,
      org_id: user.org_id,
      reason: "Deactivated by org admin via team management panel",
      deactivated_by: user.id
    }

    case Nexus.App.dispatch(command,
           metadata: %{"idempotency_key" => "deactivate:#{user_id}:#{user.id}"}
         ) do
      :ok ->
        Logger.info("[TeamManagement] User #{user_id} deactivated by #{user.id}")

        Process.send_after(self(), :reload_members, 500)

        {:noreply,
         socket
         |> assign(:confirm_deactivate, nil)
         |> put_flash(:info, "Member deactivated.")}

      {:error, reason} ->
        Logger.error("[TeamManagement] DeactivateUser failed: #{inspect(reason)}")

        {:noreply,
         socket
         |> assign(:confirm_deactivate, nil)
         |> assign(:action_error, "Failed to deactivate member. Please try again.")}
    end
  end

  @impl true
  def handle_event("open_role_change", %{"user_id" => user_id}, socket) do
    member = Enum.find(socket.assigns.members, &(&1.id == user_id))
    {:noreply, assign(socket, role_change: member, action_error: nil)}
  end

  @impl true
  def handle_event("cancel_role_change", _params, socket) do
    {:noreply, assign(socket, role_change: nil)}
  end

  @impl true
  def handle_event("confirm_role_change", %{"user_id" => user_id, "new_role" => new_role}, socket) do
    user = socket.assigns.current_user

    command = %UpdateUserRole{
      user_id: user_id,
      org_id: user.org_id,
      new_role: new_role,
      changed_by: user.id
    }

    case Nexus.App.dispatch(command,
           metadata: %{"idempotency_key" => "role_change:#{user_id}:#{new_role}:#{user.id}"}
         ) do
      :ok ->
        Logger.info("[TeamManagement] Role of #{user_id} changed to #{new_role} by #{user.id}")

        Process.send_after(self(), :reload_members, 500)

        {:noreply,
         socket
         |> assign(:role_change, nil)
         |> put_flash(:info, "Role updated to #{new_role}.")}

      {:error, :role_unchanged} ->
        {:noreply,
         socket
         |> assign(:role_change, nil)
         |> assign(:action_error, "User already has that role.")}

      {:error, reason} ->
        Logger.error("[TeamManagement] UpdateUserRole failed: #{inspect(reason)}")

        {:noreply,
         socket
         |> assign(:role_change, nil)
         |> assign(:action_error, "Failed to update role. Please try again.")}
    end
  end

  @impl true
  def handle_info(:reload_members, socket) do
    members = ListOrgMembers.execute(socket.assigns.current_user.org_id)
    {:noreply, assign(socket, :members, members)}
  end

  # ── Private ─────────────────────────────────────────────────────────────────

  defp filter_members(members, ""), do: members

  defp filter_members(members, query) do
    q = String.downcase(query)

    Enum.filter(members, fn m ->
      String.contains?(String.downcase(m.name), q) or
        String.contains?(String.downcase(m.email), q)
    end)
  end

  defp assignable_roles do
    Roles.all_org() |> Enum.reject(&(&1 in ~w(org_admin group_treasurer)))
  end

  defp can_manage_team?(user) do
    user.role in ~w(org_admin group_treasurer admin) ||
      user.platform_role in ~w(super_admin platform_support)
  end
end
