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

      {:ok,
       socket
       |> assign(:page_title, "Team Management")
       |> assign(:members, members)
       |> assign(:confirm_deactivate, nil)
       |> assign(:role_change, nil)
       |> assign(:selected_role, nil)
       |> assign(:action_error, nil)}
    else
      {:ok,
       socket
       |> put_flash(:error, "You do not have permission to manage team members.")
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
      breadcrumb_section="Team"
    >
      <div class="p-8 bg-[#010101] min-h-full">
        <div class="max-w-5xl mx-auto">
          <%!-- Header --%>
          <div class="flex items-center justify-between mb-8">
            <div>
              <p class="text-[8px] font-mono text-zinc-600 uppercase tracking-[0.3em] mb-2">
                TEAM · ROSTER
              </p>
              <h1 class="text-2xl font-serif font-bold text-white">Team Management</h1>
              <p class="text-[10px] font-mono text-zinc-500 mt-1">
                {length(@members)} active member{if length(@members) != 1, do: "s", else: ""}
              </p>
            </div>
            <.link
              navigate={~p"/team/invite"}
              class="flex items-center gap-2 px-5 py-2.5 bg-emerald-400 text-black text-[10px] font-black uppercase tracking-[0.2em] rounded-full hover:bg-emerald-300 transition-colors"
            >
              <.icon name="hero-user-plus-mini" class="w-4 h-4" /> Invite Member
            </.link>
          </div>

          <%!-- Action error --%>
          <%= if @action_error do %>
            <div class="mb-6 p-3 bg-rose-400/10 border border-rose-400/20 rounded-xl text-[10px] font-mono text-rose-400">
              {@action_error}
            </div>
          <% end %>

          <%!-- Confirm deactivation modal --%>
          <%= if @confirm_deactivate do %>
            <div class="fixed inset-0 z-50 flex items-center justify-center bg-black/70 backdrop-blur-sm">
              <div class="w-full max-w-sm prestige-card rounded-[2rem] p-8 border border-rose-400/20">
                <div class="mb-6">
                  <div class="w-12 h-12 rounded-xl bg-rose-400/10 border border-rose-400/20 flex items-center justify-center mb-4">
                    <.icon name="hero-exclamation-triangle-mini" class="w-6 h-6 text-rose-400" />
                  </div>
                  <h2 class="text-lg font-bold text-white mb-1">Deactivate Member</h2>
                  <p class="text-[10px] font-mono text-zinc-400">
                    This will immediately revoke access for <span class="text-white">{@confirm_deactivate.name}</span>.
                    This action is logged and cannot be undone from this interface.
                  </p>
                </div>
                <div class="flex gap-3">
                  <button
                    phx-click="cancel_deactivate"
                    class="flex-1 py-3 border border-white/10 rounded-full text-[10px] font-mono text-zinc-400 uppercase tracking-widest hover:border-white/20 transition-colors"
                  >
                    Cancel
                  </button>
                  <button
                    phx-click="confirm_deactivate"
                    phx-value-user_id={@confirm_deactivate.id}
                    class="flex-1 py-3 bg-rose-500 rounded-full text-[10px] font-black text-white uppercase tracking-widest hover:bg-rose-400 transition-colors"
                  >
                    Deactivate
                  </button>
                </div>
              </div>
            </div>
          <% end %>

          <%!-- Role change modal --%>
          <%= if @role_change do %>
            <div class="fixed inset-0 z-50 flex items-center justify-center bg-black/70 backdrop-blur-sm">
              <div class="w-full max-w-sm prestige-card rounded-[2rem] p-8">
                <div class="mb-6">
                  <div class="w-12 h-12 rounded-xl bg-emerald-400/10 border border-emerald-400/20 flex items-center justify-center mb-4">
                    <.icon name="hero-shield-check-mini" class="w-6 h-6 text-emerald-400" />
                  </div>
                  <h2 class="text-lg font-bold text-white mb-1">Change Role</h2>
                  <p class="text-[10px] font-mono text-zinc-400">
                    Updating role for <span class="text-white">{@role_change.name}</span>
                  </p>
                </div>

                <form phx-submit="confirm_role_change">
                  <input type="hidden" name="user_id" value={@role_change.id} />
                  <div class="mb-4">
                    <label class="text-[8px] font-mono text-zinc-600 uppercase tracking-widest block mb-1">
                      New Role
                    </label>
                    <select
                      name="new_role"
                      class="w-full bg-white/[0.04] border border-white/10 rounded-xl px-3 py-2.5 text-[11px] font-mono text-white/90 focus:outline-none focus:border-emerald-400/40 appearance-none"
                      phx-change="select_role"
                    >
                      <%= for role <- assignable_roles() do %>
                        <option value={role} selected={role == @role_change.role}>
                          {role}
                        </option>
                      <% end %>
                    </select>
                  </div>
                  <div class="flex gap-3 mt-6">
                    <button
                      type="button"
                      phx-click="cancel_role_change"
                      class="flex-1 py-3 border border-white/10 rounded-full text-[10px] font-mono text-zinc-400 uppercase tracking-widest hover:border-white/20 transition-colors"
                    >
                      Cancel
                    </button>
                    <button
                      type="submit"
                      class="flex-1 py-3 bg-emerald-400 rounded-full text-[10px] font-black text-black uppercase tracking-widest hover:bg-emerald-300 transition-colors"
                    >
                      Update Role
                    </button>
                  </div>
                </form>
              </div>
            </div>
          <% end %>

          <%!-- Member table --%>
          <div class="prestige-card rounded-[2rem] overflow-hidden">
            <%!-- Table header --%>
            <div class="grid grid-cols-[1fr_120px_120px_100px] gap-4 px-6 py-3 border-b border-white/5 bg-white/[0.02]">
              <span class="text-[8px] font-mono text-zinc-600 uppercase tracking-[0.25em]">
                Member
              </span>
              <span class="text-[8px] font-mono text-zinc-600 uppercase tracking-[0.25em]">Role</span>
              <span class="text-[8px] font-mono text-zinc-600 uppercase tracking-[0.25em]">
                Status
              </span>
              <span class="text-[8px] font-mono text-zinc-600 uppercase tracking-[0.25em]">
                Actions
              </span>
            </div>

            <%= if @members == [] do %>
              <div class="px-6 py-12 text-center">
                <p class="text-[10px] font-mono text-zinc-600 uppercase tracking-widest">
                  No active team members
                </p>
              </div>
            <% end %>

            <%= for member <- @members do %>
              <div class="grid grid-cols-[1fr_120px_120px_100px] gap-4 px-6 py-4 border-b border-white/5 hover:bg-white/[0.02] transition-colors items-center group">
                <%!-- Identity --%>
                <div class="flex items-center gap-3 min-w-0">
                  <div class="w-8 h-8 rounded-full bg-emerald-400/10 border border-emerald-400/20 flex items-center justify-center flex-shrink-0">
                    <span class="text-[10px] font-bold text-emerald-400">
                      {member.name |> String.first() |> String.upcase()}
                    </span>
                  </div>
                  <div class="min-w-0">
                    <p class="text-[11px] font-bold text-white truncate">{member.name}</p>
                    <p class="text-[9px] font-mono text-zinc-500 truncate">{member.email}</p>
                  </div>
                </div>

                <%!-- Role --%>
                <div>
                  <span class="text-[9px] font-mono text-zinc-300 uppercase">{member.role}</span>
                </div>

                <%!-- Status badge --%>
                <div>
                  <span class={[
                    "text-[8px] font-mono uppercase tracking-widest px-2 py-0.5 rounded-full",
                    member.status == "active" &&
                      "text-emerald-400 bg-emerald-400/10 border border-emerald-400/20",
                    member.status in ~w(invited registered) &&
                      "text-amber-400 bg-amber-400/10 border border-amber-400/20",
                    member.status == "pending_kyb" &&
                      "text-blue-400 bg-blue-400/10 border border-blue-400/20"
                  ]}>
                    {member.status}
                  </span>
                </div>

                <%!-- Actions (hide for self) --%>
                <div class="flex items-center gap-2">
                  <%= if member.id != @current_user.id do %>
                    <button
                      phx-click="open_role_change"
                      phx-value-user_id={member.id}
                      title="Change role"
                      class="p-1.5 rounded-lg text-zinc-600 hover:text-emerald-400 hover:bg-emerald-400/10 transition-all"
                    >
                      <.icon name="hero-pencil-mini" class="w-3.5 h-3.5" />
                    </button>
                    <%= if member.status not in ~w(deactivated) do %>
                      <button
                        phx-click="request_deactivate"
                        phx-value-user_id={member.id}
                        title="Deactivate"
                        class="p-1.5 rounded-lg text-zinc-600 hover:text-rose-400 hover:bg-rose-400/10 transition-all"
                      >
                        <.icon name="hero-x-mark-mini" class="w-3.5 h-3.5" />
                      </button>
                    <% end %>
                  <% else %>
                    <span class="text-[8px] font-mono text-zinc-700 uppercase">You</span>
                  <% end %>
                </div>
              </div>
            <% end %>
          </div>

          <%!-- Footer nav --%>
          <div class="mt-6 flex justify-end">
            <.link
              navigate={~p"/vaults"}
              class="text-[9px] font-mono text-zinc-600 hover:text-white transition-colors uppercase tracking-widest"
            >
              ← Back to Command Center
            </.link>
          </div>
        </div>
      </div>
    </Layouts.app>
    """
  end

  # ── Events ──────────────────────────────────────────────────────────────────

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

  defp assignable_roles do
    Roles.all_org() |> Enum.reject(&(&1 in ~w(org_admin group_treasurer)))
  end

  defp can_manage_team?(user) do
    user.role in ~w(org_admin group_treasurer admin) ||
      user.platform_role in ~w(super_admin platform_support)
  end
end
