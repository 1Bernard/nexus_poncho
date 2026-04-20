defmodule NexusWeb.Treasury.VaultRegistrationLive do
  use NexusWeb, :live_view

  alias Nexus.Treasury.Commands.RegisterVault

  @impl true
  def render(assigns) do
    ~H"""
    <div class="p-8 max-w-3xl mx-auto">
      <.eq_page_header
        section="Treasury"
        title="Register Vault"
        subtitle="Establish a new asset vault with institutional-grade controls"
      />

      <div class="vault-card rounded-2xl p-8">
        <.eq_form
          for={@form}
          id="vault_form"
          phx-submit="save"
          phx-change="validate"
        >
          <div class="grid grid-cols-1 gap-6 sm:grid-cols-2">
            <.eq_input
              field={@form[:name]}
              label="Vault Display Name"
              placeholder="e.g. Primary Operating"
              required
            />
            <.eq_select
              field={@form[:currency]}
              label="Currency"
              options={["USD", "EUR", "GBP", "SGD"]}
            />
            <.eq_input
              field={@form[:bank_name]}
              label="Partner Bank"
              placeholder="e.g. Equinox Central Bank"
              required
            />
            <.eq_input
              field={@form[:iban]}
              label="IBAN / Account Number"
              placeholder="e.g. GB29 NWBK 6016 1331 9268 19"
              required
            />
            <.eq_select
              field={@form[:provider]}
              label="Settlement Provider"
              options={["Stripe", "Modulr", "Internal"]}
            />
            <.eq_input
              field={@form[:daily_withdrawal_limit]}
              type="number"
              label="Daily Withdrawal Limit (Minor Units)"
              value="1000000"
            />
          </div>

          <div class="pt-2">
            <.eq_checkbox
              field={@form[:requires_multi_sig]}
              label="Enable Multi-Signature Approval"
            />
          </div>

          <:actions>
            <.eq_button full_width phx-disable-with="Establishing...">
              Initialize Vault
            </.eq_button>
          </:actions>
        </.eq_form>
      </div>
    </div>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     assign(socket,
       form: to_form(%{"currency" => "USD", "provider" => "Stripe"}, as: "vault"),
       page_title: "New Vault",
       breadcrumb_section: "Treasury"
     )}
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
