defmodule NexusWeb.Treasury.VaultDashboardLive do
  use NexusWeb, :live_view

  alias Nexus.Treasury.Projections.Vault

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app
      flash={@flash}
      current_user={@current_user}
      current_scope={:treasury}
      page_title={@page_title}
    >
      <div class="p-8 max-w-6xl mx-auto">
        <%!-- Page Header --%>
        <div class="flex items-center justify-between mb-10">
          <div>
            <p class="tech-label text-emerald-400 mb-2">Treasury · Command_Center</p>
            <h1 class="text-2xl font-black uppercase tracking-tight text-white">Vault Registry</h1>
            <p class="text-sm text-zinc-500 font-mono mt-1">
              Real-time asset monitoring across distributed nodes
            </p>
          </div>
          <.link
            navigate={~p"/vaults/new"}
            class="flex items-center gap-2 px-5 py-2.5 bg-emerald-400 text-black text-[11px] font-bold uppercase tracking-widest hover:bg-emerald-300 transition-colors rounded-sm"
          >
            <.icon name="hero-plus-mini" class="size-4" /> Register Vault
          </.link>
        </div>

        <%!-- Vault Grid --%>
        <%= if @vaults != [] do %>
          <div class="dashboard-grid">
            <%= for vault <- @vaults do %>
              <div class="vault-card rounded-2xl p-6">
                <div class="flex items-start justify-between mb-4">
                  <div>
                    <p class="text-[10px] font-mono text-zinc-600 uppercase tracking-widest mb-1">
                      {vault.currency}
                    </p>
                    <h3 class="text-base font-bold text-white">{vault.name}</h3>
                    <p class="text-xs text-zinc-500 mt-0.5">{vault.bank_name}</p>
                  </div>
                  <span class={[
                    "text-[9px] font-mono font-bold uppercase tracking-widest px-2 py-1 rounded-sm border",
                    vault.status == "active" &&
                      "text-emerald-400 border-emerald-400/30 bg-emerald-400/10",
                    vault.status != "active" && "text-zinc-500 border-zinc-700 bg-zinc-900"
                  ]}>
                    {vault.status}
                  </span>
                </div>
                <div class="mt-6 pt-4 border-t border-white/5">
                  <p class="tech-label text-zinc-600 mb-1">Balance</p>
                  <p class="text-2xl font-black font-mono text-emerald-400 tracking-tighter">
                    {Number.Currency.number_to_currency(vault.balance)}
                  </p>
                </div>
              </div>
            <% end %>
          </div>
        <% else %>
          <div class="flex flex-col items-center justify-center py-32 border border-dashed border-white/10 rounded-2xl">
            <.icon name="hero-building-library" class="size-10 text-zinc-700 mb-4" />
            <p class="text-zinc-500 font-mono text-sm">No vaults established yet.</p>
            <p class="text-zinc-700 text-xs mt-1">Step into the Treasury to begin.</p>
            <.link
              navigate={~p"/vaults/new"}
              class="mt-6 px-5 py-2 border border-emerald-400/40 text-emerald-400 text-[10px] font-mono uppercase tracking-widest hover:bg-emerald-400/10 transition-colors rounded-sm"
            >
              Register First Vault
            </.link>
          </div>
        <% end %>
      </div>
    </Layouts.app>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    vaults = Nexus.Repo.all(Vault)
    {:ok, assign(socket, vaults: vaults, page_title: "Vaults", breadcrumb_section: "Treasury")}
  end
end
