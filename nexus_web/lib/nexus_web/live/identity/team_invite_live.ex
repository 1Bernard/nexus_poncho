defmodule NexusWeb.Identity.TeamInviteLive do
  use NexusWeb, :live_view

  alias Nexus.Identity.Commands.InviteTeamMember
  alias Nexus.Identity.WebAuthn.BiometricInvitation
  alias NexusShared.Identity.Roles
  alias NexusWeb.InvitationEmail
  require Logger

  @impl true
  def mount(_params, _session, socket) do
    user = socket.assigns.current_user

    if user && user.role in ~w(org_admin group_treasurer) do
      {:ok,
       socket
       |> assign(:page_title, "Invite Team Member")
       |> assign(:form, %{"name" => "", "email" => "", "role" => ""})
       |> assign(:errors, %{})
       |> assign(:error, nil)
       |> assign(:success, nil)}
    else
      {:ok,
       socket
       |> put_flash(:error, "Only org admins can invite team members.")
       |> push_navigate(to: ~p"/vaults")}
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
      <div class="min-h-full p-8 flex flex-col items-center justify-center relative bg-[#010101]">
        <div class="bg-grid-elite"></div>

        <div class="w-full max-w-[480px] prestige-card rounded-[2.5rem] relative overflow-hidden">
          <div class="flex gap-2 p-8 pb-0">
            <span class="h-1 w-10 rounded-full bg-emerald-400 shadow-[0_0_15px_rgba(52,211,153,0.9)]">
            </span>
          </div>

          <div class="px-8 pb-10 pt-6">
            <div class="mb-6">
              <div class="w-14 h-14 rounded-2xl bg-emerald-400/10 border border-emerald-400/20 flex items-center justify-center mb-4">
                <.icon name="hero-user-plus" class="w-7 h-7 text-emerald-400" />
              </div>
              <h1 class="text-2xl font-serif font-bold text-white mb-1">Invite Team Member</h1>
              <p class="text-[9px] font-mono text-zinc-500 uppercase tracking-[0.2em]">
                Send a biometric onboarding invitation
              </p>
            </div>

            <%= if @success do %>
              <div class="p-4 bg-emerald-400/10 border border-emerald-400/20 rounded-2xl mb-4">
                <p class="text-[10px] font-mono text-emerald-400 font-bold uppercase tracking-widest mb-1">
                  Invitation Sent
                </p>
                <p class="text-[10px] font-mono text-zinc-400">{@success}</p>
              </div>
            <% end %>

            <%= if @error do %>
              <div class="p-3 bg-rose-400/10 border border-rose-400/20 rounded-xl mb-4 text-[10px] font-mono text-rose-400">
                {@error}
              </div>
            <% end %>

            <form phx-submit="send_invitation" phx-change="update_form" class="space-y-4">
              <input type="hidden" name="form[__noop]" value="1" />

              <div>
                <label class="text-[8px] font-mono text-zinc-600 uppercase tracking-widest block mb-1">
                  Full Name
                </label>
                <input
                  type="text"
                  name="form[name]"
                  value={@form["name"]}
                  placeholder="Jane Smith"
                  class={[
                    "w-full bg-white/[0.04] border rounded-xl px-3 py-2.5 text-[11px] font-mono text-white/90 placeholder-zinc-700 focus:outline-none focus:border-emerald-400/40",
                    @errors["name"] && "border-rose-400/40",
                    !@errors["name"] && "border-white/10"
                  ]}
                />
                <%= if @errors["name"] do %>
                  <p class="text-[9px] font-mono text-rose-400 mt-1">{@errors["name"]}</p>
                <% end %>
              </div>

              <div>
                <label class="text-[8px] font-mono text-zinc-600 uppercase tracking-widest block mb-1">
                  Email Address
                </label>
                <input
                  type="email"
                  name="form[email]"
                  value={@form["email"]}
                  placeholder="jane.smith@company.com"
                  class={[
                    "w-full bg-white/[0.04] border rounded-xl px-3 py-2.5 text-[11px] font-mono text-white/90 placeholder-zinc-700 focus:outline-none focus:border-emerald-400/40",
                    @errors["email"] && "border-rose-400/40",
                    !@errors["email"] && "border-white/10"
                  ]}
                />
                <%= if @errors["email"] do %>
                  <p class="text-[9px] font-mono text-rose-400 mt-1">{@errors["email"]}</p>
                <% end %>
              </div>

              <div>
                <label class="text-[8px] font-mono text-zinc-600 uppercase tracking-widest block mb-1">
                  Role
                </label>
                <select
                  name="form[role]"
                  class={[
                    "w-full bg-white/[0.04] border rounded-xl px-3 py-2.5 text-[11px] font-mono text-white/90 focus:outline-none focus:border-emerald-400/40 appearance-none",
                    @errors["role"] && "border-rose-400/40",
                    !@errors["role"] && "border-white/10"
                  ]}
                >
                  <option value="">Select a role</option>
                  <%= for role <- team_member_roles() do %>
                    <option value={role} selected={@form["role"] == role}>{role}</option>
                  <% end %>
                </select>
                <%= if @errors["role"] do %>
                  <p class="text-[9px] font-mono text-rose-400 mt-1">{@errors["role"]}</p>
                <% end %>
              </div>

              <button
                type="submit"
                class="cta-primary w-full mt-2 py-4 bg-emerald-400 text-black rounded-full text-[10px] font-black uppercase tracking-[0.3em] flex items-center justify-center gap-3 shadow-[0_10px_30px_rgba(52,211,153,0.1)]"
              >
                Send Invitation
                <span class="arrow-wrap">
                  <.icon name="hero-arrow-up-right" class="w-4 h-4 arrow-icon" />
                  <.icon name="hero-arrow-up-right" class="w-4 h-4 arrow-clone" />
                </span>
              </button>
            </form>
          </div>

          <div class="border-t border-white/5 px-8 py-4 flex items-center justify-between text-white/30 text-[8px] font-mono tracking-widest">
            <span>EQUINOX · TEAM ACCESS</span>
            <.link navigate={~p"/vaults"} class="hover:text-white/60 transition-colors">← Back</.link>
          </div>
        </div>
      </div>
    </Layouts.app>
    """
  end

  @impl true
  def handle_event("update_form", %{"form" => params}, socket) do
    {:noreply, assign(socket, form: Map.merge(socket.assigns.form, params))}
  end

  @impl true
  def handle_event("send_invitation", %{"form" => params}, socket) do
    form = Map.merge(socket.assigns.form, params)
    errors = validate_invite_form(form)

    if map_size(errors) == 0 do
      dispatch_invitation(form, socket)
    else
      {:noreply, assign(socket, form: form, errors: errors, error: nil, success: nil)}
    end
  end

  defp dispatch_invitation(form, socket) do
    user = socket.assigns.current_user
    invitee_user_id = Uniq.UUID.uuid7()

    command = %InviteTeamMember{
      user_id: invitee_user_id,
      org_id: user.org_id,
      invited_by: user.id,
      email: form["email"],
      name: form["name"],
      role: form["role"]
    }

    case Nexus.App.dispatch(command,
           metadata: %{"idempotency_key" => "invite:#{user.org_id}:#{form["email"]}"}
         ) do
      :ok ->
        token = BiometricInvitation.generate_token(invitee_user_id)
        link = BiometricInvitation.magic_link(token)

        Task.start(fn ->
          InvitationEmail.send_biometric_invitation(
            form["name"],
            form["email"],
            form["role"],
            link
          )
        end)

        Logger.info(
          "[TeamInvite] Invitation dispatched for #{form["email"]} (role: #{form["role"]})"
        )

        {:noreply,
         socket
         |> assign(:form, %{"name" => "", "email" => "", "role" => ""})
         |> assign(:errors, %{})
         |> assign(:error, nil)
         |> assign(
           :success,
           "Invitation sent to #{form["email"]}. They will receive a biometric enrollment link via email."
         )}

      {:error, reason} ->
        Logger.error("[TeamInvite] InviteTeamMember failed: #{inspect(reason)}")
        {:noreply, assign(socket, :error, "Failed to send invitation. Please try again.")}
    end
  end

  defp validate_invite_form(form) do
    required = ~w(name email role)

    errors =
      Enum.reduce(required, %{}, fn field, acc ->
        if form[field] == nil || String.trim(form[field]) == "" do
          Map.put(acc, field, "Required")
        else
          acc
        end
      end)

    if form["email"] && !String.contains?(form["email"], "@") do
      Map.put(errors, "email", "Must be a valid email address")
    else
      errors
    end
  end

  defp team_member_roles do
    Roles.all() |> Enum.reject(&(&1 in ~w(org_admin group_treasurer)))
  end
end
