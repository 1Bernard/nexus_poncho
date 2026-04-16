defmodule NexusWeb.Identity.OnboardingLive do
  use NexusWeb, :live_view

  alias Nexus.Identity.Commands.EnrollBiometric
  alias Nexus.Identity.Queries.GetUser
  alias Nexus.Identity.WebAuthn
  alias Nexus.Identity.WebAuthn.BiometricInvitation
  require Logger

  @impl true
  def mount(%{"token" => token}, _session, socket) do
    Logger.info("[OnboardingUI] Verifying invitation token: #{token}")
    case BiometricInvitation.verify_token(token) do
      {:ok, user_id} ->
        user = GetUser.execute(user_id)

        if user do
          Logger.info("[OnboardingUI] Handshake authorized for user: #{user_id}")

          {:ok,
           socket
           |> assign(:user_id, user_id)
           |> assign(:user, user)
           |> assign(token: token)
           |> assign(status: :idle)
           |> assign(progress: 0)
           |> assign(current_origin: nil)
           |> assign(error: nil)}
        else
          Logger.warning("[OnboardingUI] Handshake failed: User #{user_id} not yet projected.")

          {:ok,
           socket
           |> put_flash(:error, "Identity record not ready. Please refresh in a moment.")
           |> push_navigate(to: "/register")}
        end

      {:error, reason} ->
        Logger.warning("[OnboardingUI] Handshake failed: #{inspect(reason)}")
        {:ok, redirect(socket, to: "/")}
    end
  end

  def mount(_params, _session, socket) do
    {:ok, redirect(socket, to: "/")}
  end

  @impl true
  def handle_params(_params, uri, socket) do
    # Elite Standard: Detect current origin at runtime from the request URI
    uri_struct = URI.parse(uri)
    origin = "#{uri_struct.scheme}://#{uri_struct.host}#{if uri_struct.port, do: ":#{uri_struct.port}"}"

    {:noreply, assign(socket, current_origin: origin)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="mx-auto max-w-md mt-20">
      <div class="relative p-8 overflow-hidden bg-white dark:bg-zinc-900 border border-zinc-200 dark:border-zinc-800 rounded-2xl shadow-xl">
        <div class="absolute inset-0 bg-gradient-to-br from-indigo-500/5 to-transparent pointer-events-none" />

        <div class="relative z-10 text-center">
          <.header>
            Secure Enrollment
            <:subtitle>
              Securely anchoring your biometric identity to <span class="font-mono text-xs font-bold text-indigo-500">SecureFlow ID</span>
            </:subtitle>
          </.header>

          <div class="mt-12 flex flex-col items-center">
            <%!-- Biometric Scanner UI --%>
            <div
              id="biometric-trigger"
              phx-hook="OnboardingLive"
              data-user-id={@user_id}
              class="relative group cursor-pointer no-select"
            >
              <%!-- SVG Progress Ring --%>
              <svg class="w-48 h-48">
                <circle
                  class="text-zinc-100 dark:text-zinc-800 stroke-current"
                  stroke-width="4"
                  fill="transparent"
                  r="90"
                  cx="96"
                  cy="96"
                />
                <circle
                  class="text-indigo-500 progress-ring__circle stroke-current"
                  stroke-width="4"
                  stroke-dasharray="565.48"
                  stroke-dashoffset={565.48 * (1 - @progress / 100)}
                  stroke-linecap="round"
                  fill="transparent"
                  r="90"
                  cx="96"
                  cy="96"
                />
              </svg>

              <%!-- Fingerprint Icon & Scan Beam --%>
              <div class="absolute inset-0 flex items-center justify-center">
                <div class={[
                  "w-32 h-32 rounded-full flex items-center justify-center transition-all duration-500",
                  @status == :scanning && "bg-indigo-500/10 scale-110",
                  @status == :complete && "bg-emerald-500/10 scale-110",
                  @status == :idle && "bg-zinc-50 dark:bg-zinc-800 group-hover:bg-indigo-500/5"
                ]}>
                  <div class="relative overflow-hidden w-20 h-20">
                    <.icon
                      name="hero-finger-print"
                      class={
                        [
                          "w-20 h-20 transition-colors duration-500",
                          @status == :complete && "text-emerald-500",
                          @status == :scanning && "text-indigo-500 pulse-soft",
                          @status == :idle && "text-zinc-400 dark:text-zinc-600 group-hover:text-indigo-400"
                        ]
                        |> Enum.filter(& &1)
                        |> Enum.join(" ")
                      }
                    />

                    <%= if @status == :scanning do %>
                      <div class="absolute inset-0 bg-indigo-500/30 animate-scan-beam" />
                    <% end %>
                  </div>
                </div>
              </div>
            </div>

            <div class="mt-8 space-y-2">
              <h3 class={[
                "text-lg font-semibold tracking-tight transition-colors duration-500",
                @status == :complete && "text-emerald-500",
                @status == :scanning && "text-indigo-500",
                @status == :idle && "text-zinc-900 dark:text-zinc-100"
              ]}>
                <%= case @status do %>
                  <% :idle -> %> Scan Biometric
                  <% :scanning -> %> Hardware Handshake in Progress...
                  <% :complete -> %> Neural profile secured
                  <% :error -> %> Handshake Aborted
                <% end %>
              </h3>

              <p class="text-sm text-zinc-500 dark:text-zinc-400 max-w-[280px] mx-auto leading-relaxed">
                <%= case @status do %>
                  <% :idle -> %> Please prepare your biometric authenticator (TouchID, FaceID, or YubiKey).
                  <% :scanning -> %> Holding secure tunnel to authenticator. Please provide biometric verification.
                  <% :complete -> %> Biometric vault synchronized.
                  <% :error -> %> {@error}
                <% end %>
              </p>
            </div>

            <%= if @status == :idle do %>
              <.button
                id="enroll-button"
                phx-click={JS.push("biometric_start") |> JS.dispatch("nx:biometric-start", to: "#biometric-trigger")}
                class="mt-10 px-8 py-3 bg-indigo-600 hover:bg-indigo-700 text-white rounded-full font-bold shadow-lg shadow-indigo-500/20 active:scale-95 transition-all"
              >
                Enroll Biometrics
              </.button>
            <% end %>

            <%= if @status == :complete do %>
              <.button
                navigate={~p"/"}
                class="mt-10 px-8 py-3 bg-emerald-600 hover:bg-emerald-700 text-white rounded-full font-bold shadow-lg shadow-emerald-500/20 active:scale-95 transition-all"
              >
                Identity Verified - Enter
              </.button>
            <% end %>
          </div>
        </div>
      </div>
    </div>
    """
  end

  @impl true
  def handle_event("verify_identity", _params, socket) do
    {:noreply,
     socket
     |> assign(:status, :complete)
     |> assign(:progress, 100)}
  end

  @impl true
  def handle_event("biometric_start", _params, socket) do
    user = socket.assigns[:user]

    if user do
      Logger.info("[OnboardingUI] Biometric start requested for user: #{socket.assigns.user_id}")

      # 1. Generate challenge via WebAuthn adapter with dynamic origin support
      case WebAuthn.register_begin(socket.assigns.user_id, user.email, origin: socket.assigns.current_origin) do
        {:ok, challenge} ->
          # 2. Push challenge to client JS hook
          # We must encode the challenge binary to Base64 for the JS hook
          {:noreply,
           socket
           |> assign(:status, :scanning)
           |> assign(:progress, 33)
           |> push_event("biometric_challenge", %{challenge: Base.encode64(challenge.bytes)})}

        {:error, reason} ->
          Logger.error("[OnboardingUI] Challenge failed: #{inspect(reason)}")
          {:noreply, assign(socket, status: :error, error: "Challenge failed: #{inspect(reason)}")}
      end
    else
      Logger.error("[OnboardingUI] Biometric start failed: User not found in assigns.")
      {:noreply,
       socket
       |> put_flash(:error, "Session expired or invalid. Please reload.")
       |> push_navigate(to: "/register")}
    end
  end

  @impl true
  def handle_event("biometric_complete", %{"attestation" => attestation}, socket) do
    Logger.info("[OnboardingUI] Biometric attestation received. Verifying...")
    Logger.debug("[OnboardingUI] Attestation ID length: #{String.length(attestation["id"] || "")}")

    try do
      case WebAuthn.register_finish(attestation, socket.assigns.user_id, socket.assigns.user_id) do
        {:ok, %{auth_data: %{credential_id: credential_id, cose_key: cose_key}}} ->
          enroll_credential(credential_id, cose_key, socket)

        {:error, reason} ->
          Logger.error("[OnboardingUI] Attestation verification failed: #{inspect(reason)}")
          {:noreply, assign(socket, status: :error, error: format_webauthn_error(reason))}
      end
    rescue
      err ->
        Logger.error("[OnboardingUI] CRITICAL CRASH during biometric verification: #{inspect(err)}")
        {:noreply,
         socket
         |> assign(:status, :error)
         |> assign(:error, "The hardware handshake failed due to an internal error. Please try again.")}
    end
  end

  @impl true
  def handle_event("biometric_error", %{"reason" => reason}, socket) do
    Logger.warning("[OnboardingUI] Biometric handshake failed on client: #{reason}")

    clean_reason =
      if String.contains?(reason, "focus") do
        "Security focus lost: Please click the fingerprint scanner directly to grant authenticator focus."
      else
        "Handshake failed: #{reason}"
      end

    {:noreply,
     socket
     |> assign(:status, :error)
     |> assign(:error, clean_reason)}
  end

  defp enroll_credential(credential_id, cose_key, socket) do
    command = %EnrollBiometric{
      user_id: socket.assigns.user_id,
      org_id: socket.assigns.user.org_id,
      credential_id: Base.encode64(credential_id, padding: false),
      cose_key: Base.encode64(:erlang.term_to_binary(cose_key), padding: false)
    }

    case Nexus.App.dispatch(command) do
      result when result == :ok or (is_tuple(result) and elem(result, 0) == :ok) ->
        Logger.info("[OnboardingUI] Identity anchored to hardware for user: #{socket.assigns.user_id}")

        {:noreply,
         socket
         |> assign(:status, :complete)
         |> assign(:progress, 100)
         |> put_flash(:info, "Identity successfully anchored!")
         |> push_navigate(to: ~p"/onboarding/success")}

      {:error, reason} ->
        Logger.error("[OnboardingUI] Command dispatch failed: #{inspect(reason)}")
        {:noreply, assign(socket, status: :error, error: "Command failed: #{inspect(reason)}")}
    end
  end

  defp format_webauthn_error(%Wax.InvalidClientDataError{reason: :origin_mismatch}) do
    "Address mismatch: Please ensure you are using the same URL that provided your invitation (check Port 4000 vs 4001)."
  end

  defp format_webauthn_error(reason), do: "Verification failed: #{inspect(reason)}"
end
