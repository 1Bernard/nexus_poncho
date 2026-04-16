defmodule NexusWeb.Treasury.VaultDashboardLive do
  use NexusWeb, :live_view

  alias Nexus.Treasury.Projections.Vault

  @impl true
  def render(assigns) do
    ~H"""
    <div class="mx-auto max-w-4xl">
      <.header>
        Treasury Vaults
        <:subtitle>Real-time asset monitoring across distributed nodes</:subtitle>
        <:actions>
          <.link navigate={~p"/vaults/new"} class="bg-blue-600 px-3 py-1 font-semibold text-white rounded-md">
            + New Vault
          </.link>
        </:actions>
      </.header>

      <div class="mt-8 grid grid-cols-1 gap-4 sm:grid-cols-2">
        <%= for vault <- @vaults do %>
          <div class="rounded-xl border border-gray-200 bg-white p-6 shadow-sm">
            <div class="flex items-center justify-between">
              <h3 class="text-lg font-bold text-gray-900">{vault.name}</h3>
              <span class="rounded bg-gray-100 px-2 py-1 text-xs font-medium text-gray-600">
                {vault.currency}
              </span>
            </div>
            <p class="mt-2 text-sm text-gray-500">{vault.bank_name}</p>
            <div class="mt-6 flex items-baseline gap-2">
              <span class="text-3xl font-bold tracking-tight text-indigo-600">
                {Number.Currency.number_to_currency(vault.balance)}
              </span>
              <span class="text-sm font-medium text-gray-400 capitalize">{vault.status}</span>
            </div>
          </div>
        <% end %>
      </div>

      <%= if @vaults == [] do %>
        <div class="mt-12 text-center py-20 border-2 border-dashed border-gray-200 rounded-lg">
          <p class="text-gray-500">No vaults established yet. Step into the Treasury to begin.</p>
        </div>
      <% end %>
    </div>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    # In a real Poncho app, we would query the core Repo via the Core node.
    # For now, we assume simple DB access.
    vaults = Nexus.Repo.all(Vault)
    {:ok, assign(socket, vaults: vaults)}
  end
end
