defmodule NexusWeb.Treasury.VaultRegistrationLive do
  use NexusWeb, :live_view

  alias Nexus.Treasury.Commands.RegisterVault

  @impl true
  def render(assigns) do
    ~H"""
    <div class="mx-auto max-w-2xl px-4 py-8">
      <.header>
        Establish New Vault
        <:subtitle>Secure asset allocation with institutional grade precision</:subtitle>
      </.header>

      <.simple_form
        for={@form}
        id="vault_form"
        phx-submit="save"
        phx-change="validate"
        class="mt-10"
      >
        <div class="grid grid-cols-1 gap-6 sm:grid-cols-2">
          <.input field={@form[:name]} label="Vault Display Name" placeholder="e.g. Primary Operating" required />
          <.input field={@form[:currency]} type="select" label="Currency" options={["USD", "EUR", "GBP", "SGD"]} />
          
          <.input field={@form[:bank_name]} label="Partner Bank" placeholder="Equinox Central Bank" required />
          <.input field={@form[:iban]} label="IBAN / Account Number" required />
          
          <.input field={@form[:provider]} type="select" label="Settlement Provider" options={["Stripe", "Modulr", "Internal"]} />
          <.input field={@form[:daily_withdrawal_limit]} type="number" label="Daily Withdrawal Limit (Minor Units)" value="1000000" />
        </div>

        <div class="mt-4">
          <.input field={@form[:requires_multi_sig]} type="checkbox" label="Enable Multi-Signature Approval" />
        </div>

        <:actions>
          <.button phx-disable-with="Establishing..." class="w-full sm:w-auto">
            Initialize Vault
          </.button>
        </:actions>
      </.simple_form>
    </div>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, form: to_form(%{"currency" => "USD", "provider" => "Stripe"}, as: "vault"))}
  end

  @impl true
  def handle_event("validate", %{"vault" => vault_params}, socket) do
    {:noreply, assign(socket, form: to_form(vault_params, as: "vault"))}
  end

  @impl true
  def handle_event("save", %{"vault" => vault_params}, socket) do
    vault_id = Uniq.UUID.uuid7()
    org_id = Uniq.UUID.uuid7()

    command = %RegisterVault{
      vault_id: vault_id,
      org_id: org_id,
      name: vault_params["name"],
      currency: vault_params["currency"],
      bank_name: vault_params["bank_name"],
      account_number: vault_params["iban"],
      iban: vault_params["iban"],
      provider: vault_params["provider"],
      daily_withdrawal_limit: Decimal.new(vault_params["daily_withdrawal_limit"] || "0"),
      requires_multi_sig: vault_params["requires_multi_sig"] == "true"
    }

    case Nexus.App.dispatch(command) do
      :ok ->
        {:noreply,
         socket
         |> put_flash(:info, "Vault successfully established in the Treasury!")
         |> push_navigate(to: ~p"/vaults")}

      {:error, reason} ->
        {:noreply, put_flash(socket, :error, "Failed to establish vault: #{inspect(reason)}")}
    end
  end
end
