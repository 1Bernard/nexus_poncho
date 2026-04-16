defmodule NexusWeb.Identity.UserRegistrationLive do
  use NexusWeb, :live_view

  alias Nexus.App
  alias Nexus.Identity.Commands.RegisterUser
  alias Nexus.Identity.WebAuthn.BiometricInvitation
  alias Nexus.Shared.Tracing

  @impl true
  def render(assigns) do
    ~H"""
    <div class="mx-auto max-w-sm">
      <.header class="text-center">
        Register for Nexus Poncho
        <:subtitle>
          The Elite Standard in Modular Ledger Architecture
          <br />
          <span class="text-xs font-semibold uppercase tracking-wider text-indigo-600">
            Biometric-Anchored Identity (WebAuthn)
          </span>
        </:subtitle>
      </.header>

      <%= if @success_link do %>
        <div class="mt-10 p-6 bg-emerald-50 dark:bg-emerald-950/20 border border-emerald-200 dark:border-emerald-800 rounded-xl text-center">
          <.icon name="hero-check-circle" class="w-12 h-12 text-emerald-500 mx-auto" />
          <h3 class="mt-4 text-lg font-bold text-zinc-900 dark:text-zinc-100">Identity Provisioned</h3>
          <p class="mt-2 text-sm text-zinc-600 dark:text-zinc-400">
            User registered successfully. An invitation link has been generated to anchor your biometric identity.
          </p>
          <div class="mt-4 p-3 bg-zinc-100 dark:bg-zinc-800 rounded border border-zinc-200 dark:border-zinc-700 break-all text-xs font-mono">
            <a href={@success_link} class="text-indigo-600 hover:text-indigo-500 underline">
              {@success_link}
            </a>
          </div>
          <.button phx-click={JS.patch(~p"/register")} class="mt-8 w-full bg-zinc-200 hover:bg-zinc-300 text-zinc-900 border-0">
            Register Another
          </.button>
        </div>
      <% else %>
        <.simple_form
          for={@form}
          id="registration_form"
          phx-submit="save"
          phx-change="validate"
        >
          <.input field={@form[:email]} type="email" label="Email" required />
          <.input field={@form[:name]} type="text" label="Full Name" required />
          <.input field={@form[:role]} type="select" label="Initial Role" options={["admin", "treasurer", "viewer"]} />

          <:actions>
            <.button phx-disable-with="Registering..." class="w-full">
              Create Account
            </.button>
          </:actions>
        </.simple_form>
      <% end %>
    </div>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(form: to_form(%{}, as: "user"))
     |> assign(current_host: nil)
     |> assign(success_link: nil)}
  end

  @impl true
  def handle_params(_params, uri, socket) do
    uri_struct = URI.parse(uri)
    base_url = "#{uri_struct.scheme}://#{uri_struct.host}#{if uri_struct.port, do: ":#{uri_struct.port}"}"

    {:noreply,
     socket
     |> assign(current_host: base_url)
     |> assign(success_link: nil)}
  end

  @impl true
  def handle_event("validate", %{"user" => user_params}, socket) do
    {:noreply, assign(socket, form: to_form(user_params, as: "user"))}
  end

  @impl true
  def handle_event("save", %{"user" => user_params}, socket) do
    user_id = Uniq.UUID.uuid7()
    org_id = Uniq.UUID.uuid7() # In a real flow, this might be picked from session

    command = %RegisterUser{
      user_id: user_id,
      org_id: org_id,
      email: user_params["email"],
      name: user_params["name"],
      role: user_params["role"],
      credential_id: nil,
      cose_key: nil
    }

    require OpenTelemetry.Tracer
    require Logger

    OpenTelemetry.Tracer.with_span "Identity.RegisterUser" do
      tracing_metadata = Tracing.inject_context(%{})

      case App.dispatch(command, metadata: tracing_metadata) do
        result when result == :ok or (is_tuple(result) and elem(result, 0) == :ok) ->
          token = BiometricInvitation.generate_token(user_id)
          link = BiometricInvitation.magic_link(token, base_url: socket.assigns.current_host)

          {:noreply,
           socket
           |> put_flash(:info, "User registered successfully!")
           |> assign(success_link: link)}

        {:error, reason} ->
          Logger.error("[Registration] Dispatch failed: #{inspect(reason)}")
          {:noreply, put_flash(socket, :error, "Registration failed: #{inspect(reason)}")}
      end
    end
  end
end
