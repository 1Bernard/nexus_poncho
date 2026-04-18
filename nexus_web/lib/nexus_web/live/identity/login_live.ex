defmodule NexusWeb.Identity.LoginLive do
  use NexusWeb, :live_view

  alias Nexus.Identity.Commands.StartSession
  alias Nexus.Identity.Queries.GetUserByCredentialId
  alias Nexus.Identity.WebAuthn

  require Logger

  @session_ttl_hours 24

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:step, :welcome)
     |> assign(:status, :idle)
     |> assign(:consent_checked, false)
     |> assign(:error, nil)
     |> assign(:challenge_id, nil)}
  end

  @impl true
  def handle_params(_params, _uri, socket), do: {:noreply, socket}

  @impl true
  def render(assigns) do
    ~H"""
    <div class="fixed inset-0 bg-[#030303]"></div>
    <div class="ambient-glow-auth"></div>
    <div class="bg-grid"></div>
    <div id="cursor-dot"></div>
    <div id="cursor-ring"></div>

    <div
      id="login-hook"
      phx-hook="LoginLive"
      class="min-h-screen flex items-center justify-center p-4 relative z-10"
    >
      <div class="w-full max-w-[460px] prestige-card rounded-[2.5rem] relative overflow-hidden">
        <%!-- Step progress dots --%>
        <div class="pt-8 px-7 pb-3 flex justify-between items-center">
          <div class="flex gap-1.5">
            <%= for {_s, i} <- Enum.with_index([:welcome, :consent, :biometric, :success]) do %>
              <div class={[
                "h-1.5 rounded-full transition-all duration-500",
                step_index(@step) == i &&
                  "w-10 bg-emerald-400 shadow-[0_0_15px_rgba(52,211,153,0.9)]",
                step_index(@step) != i && "w-4 bg-white/10"
              ]}>
              </div>
            <% end %>
          </div>
          <div class="flex items-center gap-2 px-4 py-1.5 bg-emerald-400/5 rounded-full border border-emerald-400/20">
            <span class="relative flex h-2 w-2">
              <span class="animate-ping absolute inline-flex h-full w-full rounded-full bg-emerald-400 opacity-70">
              </span>
              <span class="relative inline-flex rounded-full h-2 w-2 bg-emerald-400"></span>
            </span>
            <span class="text-[8px] font-mono font-black tracking-[0.28em] text-emerald-400 uppercase">
              ENCLAVE_ACTIVE
            </span>
          </div>
        </div>

        <%!-- Dynamic content area --%>
        <div class="px-7 pb-10 min-h-[540px] flex flex-col justify-center">
          <%= case @step do %>
            <% :welcome -> %>
              <.welcome_step />
            <% :consent -> %>
              <.consent_step consent_checked={@consent_checked} />
            <% :biometric -> %>
              <.biometric_step status={@status} error={@error} />
            <% :success -> %>
              <.success_step />
          <% end %>
        </div>

        <%!-- Compliance footer --%>
        <div class="border-t border-white/5 px-7 py-5 flex items-center justify-between text-white/30 text-[8px] font-mono tracking-widest">
          <div class="flex items-center gap-2">
            <.icon name="hero-finger-print" class="w-3 h-3 text-emerald-500/50" />
            <span>NIST_SP_800-76</span>
          </div>
          <div class="flex items-center gap-2">
            <.icon name="hero-shield-check" class="w-3 h-3 text-emerald-500/50" />
            <span>ISO_27001:2022</span>
          </div>
          <div class="flex items-center gap-2">
            <svg
              class="w-3 h-3 text-emerald-500/50"
              fill="none"
              viewBox="0 0 24 24"
              stroke="currentColor"
              stroke-width="1.5"
            >
              <path
                stroke-linecap="round"
                stroke-linejoin="round"
                d="M8.25 3v1.5M4.5 8.25H3m18 0h-1.5M4.5 12H3m18 0h-1.5m-15 3.75H3m18 0h-1.5M8.25 19.5V21M12 3v1.5m0 15V21m3.75-18v1.5m0 15V21m-9-1.5h10.5a2.25 2.25 0 002.25-2.25V6.75a2.25 2.25 0 00-2.25-2.25H6.75A2.25 2.25 0 004.5 6.75v10.5a2.25 2.25 0 002.25 2.25zm.75-12h9v9h-9v-9z"
              />
            </svg>
            <span>FIPS_140-3</span>
          </div>
        </div>
      </div>
    </div>
    """
  end

  # ── Step Components ────────────────────────────────────────────────────────

  defp welcome_step(assigns) do
    ~H"""
    <div class="space-y-7">
      <div class="w-16 h-16 rounded-2xl bg-emerald-400/10 flex items-center justify-center border border-emerald-400/20">
        <.icon name="hero-shield-check" class="w-8 h-8 text-emerald-400" />
      </div>

      <h1 class="text-3xl font-serif italic font-black tracking-tight text-white">
        Institutional<br /><span class="emerald-glint">Verification</span>
      </h1>

      <p class="text-zinc-400 text-sm leading-relaxed font-light">
        Zero-knowledge biometric handshake required for Equinox access. Secure enclave encryption active.
      </p>

      <div class="space-y-4 py-5 border-y border-white/5">
        <div class="flex gap-4 items-center">
          <div class="w-8 h-8 rounded-lg bg-white/5 flex items-center justify-center">
            <.icon name="hero-finger-print" class="w-4 h-4 text-emerald-400" />
          </div>
          <div>
            <p class="text-xs font-bold uppercase tracking-wider text-white/90">Liveness 3.0</p>
            <p class="text-[9px] text-zinc-500 font-mono">Anti-spoof / depth-mapping</p>
          </div>
        </div>
        <div class="flex gap-4 items-center">
          <div class="w-8 h-8 rounded-lg bg-white/5 flex items-center justify-center">
            <.icon name="hero-lock-closed" class="w-4 h-4 text-emerald-400" />
          </div>
          <div>
            <p class="text-xs font-bold uppercase tracking-wider text-white/90">Zero Knowledge</p>
            <p class="text-[9px] text-zinc-500 font-mono">TEE + Cryptographic sharding</p>
          </div>
        </div>
      </div>

      <button
        phx-click="advance_step"
        class="cta-primary w-full py-5 bg-emerald-400 text-black rounded-full text-[10px] font-black uppercase tracking-[0.3em] flex items-center justify-center gap-3 shadow-[0_20px_40px_rgba(52,211,153,0.15)]"
      >
        <span class="relative z-10 flex items-center gap-3">
          Initialize handshake
          <span class="arrow-wrap">
            <.icon name="hero-arrow-up-right" class="w-4 h-4 arrow-icon" />
            <.icon name="hero-arrow-up-right" class="w-4 h-4 arrow-clone" />
          </span>
        </span>
      </button>
    </div>
    """
  end

  defp consent_step(assigns) do
    ~H"""
    <div class="space-y-6">
      <h2 class="text-2xl font-serif italic font-black uppercase tracking-wide text-white">
        <span class="emerald-glint">Privacy & Consent</span>
      </h2>

      <div class="bg-white/5 border border-white/10 rounded-2xl p-5 text-xs text-zinc-300 max-h-36 overflow-y-auto leading-relaxed">
        <p class="mb-3">
          <span class="text-emerald-400 font-bold">GDPR Art. 9(2)(a)</span>
          — Explicit biometric consent for institutional verification.
        </p>
        <ul class="list-disc ml-4 space-y-1.5 text-[10px] text-zinc-400">
          <li>Biometric salted hash generation</li>
          <li>Cross-reference: global AML watchlists</li>
          <li>Data retention: 30 days post-session</li>
        </ul>
      </div>

      <label class="flex items-start gap-4 cursor-pointer group mt-4">
        <input
          type="checkbox"
          phx-click="toggle_consent"
          checked={@consent_checked}
          class="mt-1 w-5 h-5 rounded border-white/20 bg-white/5 accent-emerald-400"
        />
        <span class="text-xs text-zinc-400 group-hover:text-white transition-colors">
          I accept the
          <span class="text-emerald-400 underline underline-offset-4">institutional data notice</span>
          and consent to biometric verification.
        </span>
      </label>

      <div class="space-y-3 pt-4">
        <button
          phx-click="advance_step"
          disabled={not @consent_checked}
          class={[
            "w-full py-5 rounded-full text-[10px] font-black uppercase tracking-[0.3em] transition-all",
            @consent_checked &&
              "cta-primary bg-emerald-400 text-black shadow-[0_15px_30px_rgba(16,185,129,0.1)]",
            not @consent_checked &&
              "bg-white/5 border border-white/10 text-white/30 cursor-not-allowed"
          ]}
        >
          <span class="relative z-10">Confirm & Continue</span>
        </button>
        <button
          phx-click="back_step"
          class="w-full py-3 text-zinc-400 text-[10px] uppercase tracking-widest hover:text-white transition-colors"
        >
          ← Back
        </button>
      </div>
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
          Auth_Processing
        </h3>
        <p class="text-[9px] text-zinc-500 font-mono mt-2 uppercase tracking-widest">
          Consensus: Multi-Validator Sync
        </p>
        <div class="w-full mt-10 space-y-3 font-mono text-[9px]">
          <div class="flex justify-between p-4 bg-white/5 border border-white/10 rounded-xl">
            <span class="text-zinc-500 uppercase">Biometric Hash</span>
            <span class="text-emerald-400">0x8E...F7B</span>
          </div>
          <div class="flex justify-between p-4 bg-white/5 border border-white/10 rounded-xl">
            <span class="text-zinc-500 uppercase">Sanctions_Screen</span>
            <span class="text-emerald-400 animate-pulse">SCANNING...</span>
          </div>
        </div>
      </div>
    <% else %>
      <div class="flex flex-col items-center">
        <h2 class="text-2xl font-serif italic font-black uppercase tracking-wide text-white">
          Sensor Calibration
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
          phx-click="back_step"
          class="mt-8 text-zinc-500 text-[10px] uppercase tracking-widest hover:text-white transition-colors"
        >
          ← Back
        </button>
      </div>
    <% end %>
    """
  end

  defp success_step(assigns) do
    ~H"""
    <div class="flex flex-col items-center py-6 text-center">
      <div class="w-20 h-20 rounded-full bg-emerald-400/10 border border-emerald-400/20 flex items-center justify-center mb-8 shadow-[0_0_30px_rgba(52,211,153,0.15)]">
        <.icon name="hero-shield-check" class="w-10 h-10 text-emerald-400" />
      </div>
      <h2 class="text-3xl font-serif italic font-black uppercase tracking-wide text-white">
        Verified
      </h2>
      <p class="text-zinc-400 text-sm mt-3 mb-10 leading-relaxed">
        Identity authenticated ·<br />Institutional session active
      </p>
      <div class="w-full bg-white/5 border border-white/10 p-6 rounded-3xl mb-10 text-left font-mono">
        <div class="flex justify-between mb-2">
          <span class="text-[8px] text-zinc-500 uppercase tracking-wider">Status</span>
          <span class="text-[10px] text-emerald-400">CLASS_A_CLEARANCE</span>
        </div>
        <div class="flex justify-between">
          <span class="text-[8px] text-zinc-500 uppercase tracking-wider">Session</span>
          <span class="text-[10px] text-white/60 animate-pulse">Redirecting...</span>
        </div>
      </div>
    </div>
    """
  end

  # ── Event Handlers ────────────────────────────────────────────────────────

  @impl true
  def handle_event("advance_step", _params, socket) do
    next =
      case socket.assigns.step do
        :welcome -> :consent
        :consent -> :biometric
        _ -> socket.assigns.step
      end

    {:noreply, assign(socket, :step, next)}
  end

  @impl true
  def handle_event("back_step", _params, socket) do
    prev =
      case socket.assigns.step do
        :consent -> :welcome
        :biometric -> :consent
        _ -> socket.assigns.step
      end

    {:noreply,
     socket
     |> assign(:step, prev)
     |> assign(:status, :idle)
     |> assign(:error, nil)}
  end

  @impl true
  def handle_event("toggle_consent", _params, socket) do
    {:noreply, assign(socket, :consent_checked, !socket.assigns.consent_checked)}
  end

  @impl true
  def handle_event("biometric_login_start", _params, socket) do
    case WebAuthn.authenticate_challenge([]) do
      {:ok, challenge} ->
        challenge_id = Base.encode64(challenge.bytes)

        {:noreply,
         socket
         |> assign(:status, :scanning)
         |> assign(:challenge_id, challenge_id)
         |> push_event("login_challenge", %{challenge: challenge_id})}

      {:error, reason} ->
        Logger.error("[LoginUI] Challenge generation failed: #{inspect(reason)}")

        {:noreply,
         socket
         |> assign(:status, :error)
         |> assign(:error, "Could not initiate authentication. Please try again.")}
    end
  end

  @impl true
  def handle_event("login_verify", params, socket) do
    challenge_id = socket.assigns.challenge_id

    with {:ok, raw_id} <- decode_raw_id(params["rawId"]),
         user when not is_nil(user) <- GetUserByCredentialId.execute(raw_id),
         {:ok, cose_key} <- decode_cose_key(user.cose_key),
         {:ok, _auth} <-
           WebAuthn.verify_authentication(params, challenge_id, [{raw_id, cose_key}]),
         session_id <- Uniq.UUID.uuid7(),
         :ok <- dispatch_start_session(session_id, user, params) do
      auth_token = Phoenix.Token.sign(NexusWeb.Endpoint, "session_auth", session_id)
      redirect_url = "/auth/finalise?token=#{auth_token}"

      {:noreply,
       socket
       |> assign(:step, :success)
       |> push_event("login_success", %{redirect: redirect_url})}
    else
      nil ->
        {:noreply,
         socket
         |> assign(:status, :error)
         |> assign(:error, "No registered credential found. Please contact your administrator.")}

      {:error, reason} ->
        Logger.error("[LoginUI] Biometric verification failed: #{inspect(reason)}")

        {:noreply,
         socket
         |> assign(:status, :error)
         |> assign(:error, format_error(reason))}
    end
  end

  @impl true
  def handle_event("biometric_error", %{"reason" => reason}, socket) do
    Logger.warning("[LoginUI] Client-side biometric error: #{reason}")

    message =
      if String.contains?(reason, "focus") do
        "Security focus lost. Click the sensor directly and try again."
      else
        "Hardware authentication failed: #{reason}"
      end

    {:noreply,
     socket
     |> assign(:status, :error)
     |> assign(:error, message)}
  end

  @impl true
  def handle_event("retry", _params, socket) do
    {:noreply,
     socket
     |> assign(:status, :idle)
     |> assign(:error, nil)
     |> assign(:challenge_id, nil)}
  end

  # ── Private ───────────────────────────────────────────────────────────────

  defp step_index(:welcome), do: 0
  defp step_index(:consent), do: 1
  defp step_index(:biometric), do: 2
  defp step_index(:success), do: 3

  defp decode_raw_id(nil), do: {:error, :missing_credential}

  defp decode_raw_id(raw_id) do
    {:ok, Base.decode64!(raw_id)}
  rescue
    _ -> {:error, :invalid_credential_encoding}
  end

  defp decode_cose_key(nil), do: {:error, :no_enrolled_credential}

  defp decode_cose_key(encoded) do
    key = encoded |> Base.decode64!(padding: false) |> :erlang.binary_to_term([:safe])
    {:ok, key}
  rescue
    _ -> {:error, :invalid_cose_key}
  end

  defp dispatch_start_session(session_id, user, params) do
    expires_at =
      DateTime.utc_now()
      |> DateTime.add(@session_ttl_hours * 3600, :second)
      |> DateTime.truncate(:microsecond)

    command = %StartSession{
      session_id: session_id,
      user_id: user.id,
      org_id: user.org_id,
      credential_id: user.credential_id,
      expires_at: expires_at,
      ip_address: params["ip_address"],
      user_agent: params["user_agent"]
    }

    case Nexus.App.dispatch(command) do
      :ok -> :ok
      {:ok, _} -> :ok
      {:error, reason} -> {:error, reason}
    end
  end

  defp format_error(%Wax.InvalidClientDataError{reason: :origin_mismatch}) do
    "Origin mismatch — ensure you are using the URL from your invitation."
  end

  defp format_error(_reason), do: "Authentication could not be verified. Please try again."
end
