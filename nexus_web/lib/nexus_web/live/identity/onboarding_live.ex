defmodule NexusWeb.Identity.OnboardingLive do
  use NexusWeb, :live_view

  alias Nexus.Identity.Commands.EnrollBiometric
  alias Nexus.Identity.Queries.GetUser
  alias Nexus.Identity.WebAuthn
  alias Nexus.Identity.WebAuthn.BiometricInvitation
  require Logger

  @max_projection_retries 50
  @projection_retry_ms 200

  @impl true
  def mount(%{"token" => token}, _session, socket) do
    Logger.info("[OnboardingUI] Verifying invitation token: #{token}")

    case BiometricInvitation.verify_token(token) do
      {:ok, user_id} ->
        user = GetUser.execute(user_id)

        socket =
          socket
          |> assign(:user_id, user_id)
          |> assign(:user, user)
          |> assign(token: token)
          |> assign(step: :welcome)
          |> assign(status: if(user, do: :idle, else: :loading))
          |> assign(current_origin: nil)
          |> assign(error: nil)
          |> assign(:retry_count, 0)

        if connected?(socket) && is_nil(user) do
          Process.send_after(self(), :await_projection, @projection_retry_ms)
        end

        if user, do: Logger.info("[OnboardingUI] Handshake authorized for user: #{user_id}")

        {:ok, socket}

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
    uri_struct = URI.parse(uri)

    origin =
      "#{uri_struct.scheme}://#{uri_struct.host}#{if uri_struct.port, do: ":#{uri_struct.port}"}"

    socket = assign(socket, current_origin: origin)

    if socket.assigns.status == :loading do
      Process.send_after(self(), :await_projection, @projection_retry_ms)
    end

    {:noreply, socket}
  end

  @impl true
  def handle_info(:await_projection, %{assigns: %{user_id: user_id, retry_count: count}} = socket) do
    case GetUser.execute(user_id) do
      nil when count < @max_projection_retries ->
        Process.send_after(self(), :await_projection, @projection_retry_ms)
        {:noreply, assign(socket, retry_count: count + 1)}

      nil ->
        Logger.warning(
          "[OnboardingUI] Projection timeout: user #{user_id} not ready after #{count} retries."
        )

        {:noreply,
         socket
         |> put_flash(:error, "Identity record not ready. Please refresh in a moment.")
         |> push_navigate(to: "/register")}

      user ->
        Logger.info(
          "[OnboardingUI] Handshake authorized for user: #{user_id} (after #{count} retries)"
        )

        {:noreply, socket |> assign(:user, user) |> assign(:status, :idle)}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="fixed inset-0 bg-[#030303]"></div>
    <div class="ambient-glow-auth"></div>
    <div class="noise-overlay"></div>
    <div class="bg-grid opacity-50"></div>
    <div id="cursor-dot"></div>
    <div id="cursor-ring"></div>

    <div class="min-h-screen flex items-center justify-center px-4 relative z-10">
      <div
        id="onboarding-container"
        phx-hook="OnboardingLive"
        data-user-id={@user_id}
        class="w-full max-w-[460px] prestige-card rounded-[2.5rem] relative overflow-hidden"
      >
        <%!-- Step Progress Indicators --%>
        <div class="flex gap-2 p-8 pb-0">
          <span class={[
            "h-1 rounded-full transition-all duration-500",
            @step == :welcome && "w-10 bg-emerald-400 shadow-[0_0_15px_rgba(52,211,153,0.9)]",
            @step != :welcome && "w-4 bg-white/10"
          ]}>
          </span>
          <span class={[
            "h-1 rounded-full transition-all duration-500",
            @step == :biometric && "w-10 bg-emerald-400 shadow-[0_0_15px_rgba(52,211,153,0.9)]",
            @step != :biometric && "w-4 bg-white/10"
          ]}>
          </span>
        </div>

        <div class="px-7 pb-10 pt-4 min-h-[520px] flex flex-col justify-center">
          <%= case @step do %>
            <% :welcome -> %>
              <.welcome_step user={@user} status={@status} />
            <% :biometric -> %>
              <.biometric_step status={@status} error={@error} />
          <% end %>
        </div>

        <div class="border-t border-white/5 px-7 py-5 flex items-center justify-between text-white/30 text-[8px] font-mono tracking-widest">
          <span>EQUINOX · IDENTITY ANCHOR</span>
          <span>256-BIT WEBAUTHN</span>
        </div>
      </div>
    </div>
    """
  end

  defp welcome_step(assigns) do
    ~H"""
    <div class="flex flex-col space-y-6">
      <div class="w-16 h-16 rounded-2xl bg-emerald-400/10 flex items-center justify-center border border-emerald-400/20">
        <.icon name="hero-key" class="w-8 h-8 text-emerald-400" />
      </div>

      <div>
        <h1 class="text-3xl font-serif italic font-black tracking-tight text-white mb-2">
          Access<br /><span class="emerald-glint">Granted.</span>
        </h1>

        <p class="text-[9px] font-mono text-zinc-500 uppercase tracking-[0.2em]">
          Anchor your identity to complete onboarding
        </p>
      </div>

      <%= if @user do %>
        <div class="space-y-3 mb-10">
          <div class="group relative flex justify-between items-center p-5 bg-white/[0.03] border border-white/[0.06] rounded-2xl transition-all duration-300 hover:bg-white/[0.05] opacity-0">
            <%!-- Elite Grid Guides --%>
            <div class="grid-guide-v left-10"></div>
            <div class="grid-guide-h top-0"></div>
            <div class="grid-guide-h bottom-0"></div>

            <span class="text-[9px] font-mono text-zinc-600 uppercase tracking-[0.25em]">Name</span>
            <span class="text-[11px] font-mono font-bold text-white/90">{@user.name}</span>
          </div>

          <div class="group relative flex justify-between items-center p-5 bg-white/[0.03] border border-white/[0.06] rounded-2xl transition-all duration-300 hover:bg-white/[0.05] opacity-0">
            <%!-- Elite Grid Guides --%>
            <div class="grid-guide-v left-10"></div>
            <div class="grid-guide-h top-0"></div>
            <div class="grid-guide-h bottom-0"></div>

            <span class="text-[9px] font-mono text-zinc-600 uppercase tracking-[0.25em]">Email</span>
            <span class="text-[11px] font-mono font-bold text-white/80">{@user.email}</span>
          </div>

          <div class="group relative flex justify-between items-center p-5 bg-white/[0.03] border border-white/[0.06] rounded-2xl transition-all duration-300 hover:bg-white/[0.05] opacity-0">
            <%!-- Elite Grid Guides --%>
            <div class="grid-guide-v left-10"></div>
            <div class="grid-guide-h top-0"></div>
            <div class="grid-guide-h bottom-0"></div>

            <span class="text-[9px] font-mono text-zinc-600 uppercase tracking-[0.25em]">Role</span>
            <span class="text-[11px] font-mono font-bold text-emerald-400 uppercase tracking-widest">
              {@user.role}
            </span>
          </div>
        </div>

        <button
          phx-click="advance_to_biometric"
          class="cta-primary w-full py-5 bg-emerald-400 text-black rounded-full text-[10px] font-black uppercase tracking-[0.3em] flex items-center justify-center gap-3 shadow-[0_10px_30px_rgba(52,211,153,0.1)]"
        >
          <span class="relative z-10 flex items-center gap-3">
            Anchor Biometric Identity
            <span class="arrow-wrap">
              <.icon name="hero-arrow-up-right" class="w-4 h-4 arrow-icon" />
              <.icon name="hero-arrow-up-right" class="w-4 h-4 arrow-clone" />
            </span>
          </span>
        </button>
      <% else %>
        <div class="flex flex-col items-center py-8">
          <div class="w-8 h-8 rounded-full border-2 border-t-emerald-400 border-white/10 animate-spin mb-4">
          </div>
          <p class="text-[9px] font-mono text-zinc-500 uppercase tracking-widest">
            Resolving identity record...
          </p>
        </div>
      <% end %>
    </div>
    """
  end

  defp biometric_step(assigns) do
    ~H"""
    <%= if @status == :scanning do %>
      <div class="flex flex-col items-center py-8">
        <div class="relative w-28 h-28 mb-10">
          <div class="absolute inset-0 border-4 border-emerald-400/10 rounded-full"></div>
          <div class="absolute inset-0 border-4 border-t-emerald-400 rounded-full animate-spin"></div>
          <div class="absolute inset-0 flex items-center justify-center">
            <.icon name="hero-signal" class="w-8 h-8 text-emerald-400" />
          </div>
        </div>
        <h3 class="text-2xl font-serif italic font-black uppercase tracking-wide text-white">
          Anchoring Identity
        </h3>
        <p class="text-[9px] text-zinc-500 font-mono mt-2 uppercase tracking-widest">
          Binding credential to hardware
        </p>
        <div class="w-full mt-10 space-y-3 font-mono text-[9px]">
          <div class="flex justify-between p-4 bg-white/5 border border-white/10 rounded-xl">
            <span class="text-zinc-500 uppercase">Credential Type</span>
            <span class="text-emerald-400">WEBAUTHN PASSKEY</span>
          </div>
          <div class="flex justify-between p-4 bg-white/5 border border-white/10 rounded-xl">
            <span class="text-zinc-500 uppercase">Binding Status</span>
            <span class="text-emerald-400 animate-pulse">ENROLLING...</span>
          </div>
        </div>
      </div>
    <% else %>
      <div class="flex flex-col items-center">
        <h2 class="text-2xl font-serif font-bold uppercase tracking-wide text-white">
          Identity Anchor
        </h2>
        <p class="text-[9px] text-zinc-500 mt-2 font-mono uppercase tracking-[0.25em]">
          Liveness 3.0 · Press & Hold
        </p>

        <div class="relative my-12 flex justify-center items-center">
          <div class="absolute w-72 h-72 rounded-full border border-emerald-500/5"></div>
          <div class="absolute w-60 h-60 rounded-full border border-emerald-500/10"></div>

          <button
            id="biometric-sensor"
            class="relative w-52 h-52 rounded-full bg-emerald-500/[0.03] border border-emerald-500/20 flex items-center justify-center overflow-hidden touch-none group"
          >
            <svg class="absolute inset-0 w-full h-full -rotate-90">
              <circle
                id="scan-ring"
                cx="104"
                cy="104"
                r="100"
                fill="none"
                stroke="#34d399"
                stroke-width="2"
                stroke-dasharray="628"
                stroke-dashoffset="628"
                class="transition-none"
              />
            </svg>
            <div
              id="scan-line"
              class="absolute left-0 right-0 w-full h-[2px] bg-emerald-400 shadow-[0_0_15px_#34d399] opacity-0 pointer-events-none z-10"
            >
            </div>
            <.icon
              name="hero-finger-print"
              class="w-16 h-16 text-emerald-400/20 group-active:text-emerald-400 transition-colors duration-500"
            />
          </button>
        </div>

        <div
          id="sensor-status"
          class="h-10 text-[9px] font-mono text-zinc-500 uppercase tracking-widest"
        >
          <%= if @status == :error do %>
            <span class="text-rose-400">{@error}</span>
          <% else %>
            ⬇ Press & hold sensor ⬇
          <% end %>
        </div>

        <div class="mt-6 flex gap-3">
          <div class="w-1.5 h-1.5 rounded-full bg-emerald-400/10" id="scan-l1"></div>
          <div class="w-1.5 h-1.5 rounded-full bg-emerald-400/10" id="scan-l2"></div>
          <div class="w-1.5 h-1.5 rounded-full bg-emerald-400/10" id="scan-l3"></div>
        </div>

        <button
          phx-click="back_to_welcome"
          class="mt-8 text-zinc-500 text-[10px] uppercase tracking-widest hover:text-white transition-colors"
        >
          ← Back
        </button>
      </div>
    <% end %>
    """
  end

  @impl true
  def handle_event("advance_to_biometric", _params, socket) do
    {:noreply, assign(socket, step: :biometric, status: :idle)}
  end

  @impl true
  def handle_event("back_to_welcome", _params, socket) do
    {:noreply, assign(socket, step: :welcome, status: :idle, error: nil)}
  end

  @impl true
  def handle_event("biometric_start", _params, socket) do
    user = socket.assigns[:user]

    if user do
      Logger.info("[OnboardingUI] Biometric anchor requested for user: #{socket.assigns.user_id}")

      case WebAuthn.register_begin(socket.assigns.user_id, user.email,
             origin: socket.assigns.current_origin
           ) do
        {:ok, challenge} ->
          {:noreply,
           socket
           |> assign(:status, :scanning)
           |> push_event("biometric_challenge", %{challenge: Base.encode64(challenge.bytes)})}

        {:error, reason} ->
          Logger.error("[OnboardingUI] Challenge failed: #{inspect(reason)}")

          {:noreply,
           assign(socket, status: :error, error: "Challenge failed: #{inspect(reason)}")}
      end
    else
      Logger.error("[OnboardingUI] Biometric start failed: User not found in assigns.")

      {:noreply,
       socket
       |> put_flash(:error, "Session expired or invalid. Please reload.")
       |> push_navigate(to: "/")}
    end
  end

  @impl true
  def handle_event("biometric_complete", %{"attestation" => attestation}, socket) do
    Logger.info("[OnboardingUI] Biometric attestation received. Verifying...")

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
        Logger.error(
          "[OnboardingUI] CRITICAL CRASH during biometric verification: #{inspect(err)}"
        )

        {:noreply,
         socket
         |> assign(:status, :error)
         |> assign(
           :error,
           "The hardware handshake failed due to an internal error. Please try again."
         )}
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

    {:noreply, socket |> assign(:status, :error) |> assign(:error, clean_reason)}
  end

  defp enroll_credential(credential_id, cose_key, socket) do
    command = %EnrollBiometric{
      user_id: socket.assigns.user_id,
      org_id: socket.assigns.user.org_id,
      credential_id: Base.encode64(credential_id, padding: false),
      cose_key: Base.encode64(:erlang.term_to_binary(cose_key), padding: false)
    }

    case Nexus.App.dispatch(command, metadata: %{"idempotency_key" => socket.assigns.user_id}) do
      result when result == :ok or (is_tuple(result) and elem(result, 0) == :ok) ->
        Logger.info("[OnboardingUI] Identity anchored for user: #{socket.assigns.user_id}")

        {:noreply,
         socket
         |> assign(:status, :complete)
         |> push_navigate(to: ~p"/onboarding/success")}

      {:error, reason} ->
        Logger.error("[OnboardingUI] Command dispatch failed: #{inspect(reason)}")
        {:noreply, assign(socket, status: :error, error: "Command failed: #{inspect(reason)}")}
    end
  end

  defp format_webauthn_error(%Wax.InvalidClientDataError{reason: :origin_mismatch}) do
    "Address mismatch: Please ensure you are using the same URL that provided your invitation."
  end

  defp format_webauthn_error(reason), do: "Verification failed: #{inspect(reason)}"
end
