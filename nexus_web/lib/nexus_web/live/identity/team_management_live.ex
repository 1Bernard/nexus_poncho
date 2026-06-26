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

        <div class="max-w-7xl mx-auto space-y-8 relative z-10">
          <%!-- Page header --%>
          <div>
            <p class="text-[9px] font-mono font-bold text-emerald-400/60 uppercase tracking-[0.3em] mb-2">
              Identity · Team
            </p>
            <h1 class="text-2xl font-black text-white tracking-tight">Team Management</h1>
            <p class="text-sm text-zinc-500 mt-1">
              Manage access, roles, and onboarding for your organisation.
            </p>
          </div>

          <%!-- KPI Cards --%>
          <div class="grid grid-cols-3 gap-5">
            <.hud_metric_card
              label="Total Members"
              value={@total_members}
              color="emerald"
              status="ACTIVE"
            />
            <.hud_metric_card
              label="Admins"
              value={@admin_count}
              color="sky"
              status="PRIVILEGED"
            />
            <.hud_metric_card
              label="Viewing"
              value={length(@paginated_members)}
              color="zinc"
              status="THIS PAGE"
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
                  <h2 class="text-xl font-black text-white mb-3 tracking-tight">
                    Deactivate Member
                  </h2>
                  <p class="text-sm text-zinc-400 leading-relaxed">
                    This will immediately revoke access for <span class="text-white font-semibold">{@confirm_deactivate.name}</span>.
                    This action is recorded in the audit trail.
                  </p>
                </div>
                <div class="flex gap-3">
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
                  <h2 class="text-xl font-black text-white mb-2 tracking-tight">
                    Modify Role
                  </h2>
                  <p class="text-sm text-zinc-400">
                    Updating privileges for
                    <span class="text-white font-semibold">{@role_change.name}</span>
                  </p>
                </div>
                <.eq_form for={%{}} as={:role_update} phx-submit="confirm_role_change">
                  <input type="hidden" name="user_id" value={@role_change.id} />
                  <.eq_select
                    name="new_role"
                    label="Assigned Role"
                    options={assignable_roles()}
                    value={@role_change.role}
                  />
                  <:actions>
                    <div class="flex gap-3 mt-8">
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

          <%!-- Member table toolbar --%>
          <.eq_table_toolbar
            search_value={@search_query}
            search_event="search"
            search_name="query"
            search_placeholder="Search members..."
          >
            <:actions>
              <.eq_button navigate={~p"/team/invite"} variant="primary" class="!px-7">
                Invite Member
              </.eq_button>
            </:actions>
          </.eq_table_toolbar>

          <%!-- Member table --%>
          <div class="elite-border rounded-2xl bg-[#050508]/60 backdrop-blur-2xl overflow-hidden border border-white/5 shadow-2xl">
            <div class="overflow-auto custom-scrollbar">
              <%= if @total_count == 0 do %>
                <.ledger_empty_state
                  title="No matching members found"
                  subtitle="Try adjusting your search"
                  action_label={if @search_query != "", do: "Clear Search", else: nil}
                  action_event={if @search_query != "", do: "clear_search", else: nil}
                />
              <% else %>
                <.ledger_table id="members-roster" rows={@paginated_members} grid_guides={true}>
                  <:col :let={member} label="Member">
                    <div class="flex items-center gap-4">
                      <div class="w-9 h-9 rounded-xl bg-white/5 border border-white/[0.08] flex items-center justify-center text-[11px] font-mono font-black text-emerald-400">
                        {member.name |> String.first() |> String.upcase()}
                      </div>
                      <div>
                        <p class="text-sm font-semibold text-white">{member.name}</p>
                        <p class="text-[10px] font-mono text-zinc-500 mt-0.5">{member.email}</p>
                      </div>
                    </div>
                  </:col>

                  <:col :let={member} label="Role">
                    <div class="flex items-center gap-2.5">
                      <.icon
                        name={
                          if(member.role in ~w(admin org_admin),
                            do: "hero-shield-check-mini",
                            else: "hero-user-mini"
                          )
                        }
                        class={"w-3.5 h-3.5 " <> if(member.role in ~w(admin org_admin), do: "text-emerald-400", else: "text-zinc-600")}
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
                        class="p-2 rounded-lg bg-white/5 text-zinc-500 hover:text-emerald-400 hover:bg-emerald-400/10 transition-all group"
                        title="Edit Role"
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
                        class="p-2 rounded-lg bg-white/5 text-zinc-500 hover:text-rose-400 hover:bg-rose-400/10 transition-all"
                        title="Deactivate"
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
      </div>
    </Layouts.app>
    """
  end

  # ── Events ──────────────────────────────────────────────────────────────────

  @impl true
  def handle_event("search", %{"query" => query}, socket) do
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
