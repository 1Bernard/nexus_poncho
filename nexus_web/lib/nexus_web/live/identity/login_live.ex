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
     |> assign(:status, :idle)
     |> assign(:error, nil)
     |> assign(:challenge_id, nil)}
  end

  @impl true
  def handle_params(_params, _uri, socket), do: {:noreply, socket}

  @impl true
  def render(assigns) do
    ~H"""
    <div class="mx-auto max-w-md mt-20">
      <div class="relative p-8 overflow-hidden bg-white dark:bg-zinc-900 border border-zinc-200 dark:border-zinc-800 rounded-2xl shadow-xl">
        <div class="absolute inset-0 bg-gradient-to-br from-indigo-500/5 to-transparent pointer-events-none" />

        <div class="relative z-10 text-center">
          <.header>
            Biometric Authentication
            <:subtitle>
              Press your fingerprint to access <span class="font-mono text-xs font-bold text-indigo-500">SecureFlow</span>
            </:subtitle>
          </.header>

          <div class="mt-12 flex flex-col items-center">
            <div
              id="login-trigger"
              phx-hook="LoginLive"
              class="relative group cursor-pointer no-select"
            >
              <%!-- Progress Ring --%>
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
                  class={[
                    "stroke-current progress-ring__circle",
                    @status == :scanning && "text-indigo-500",
                    @status == :complete && "text-emerald-500",
                    @status in [:idle, :error] && "text-zinc-200 dark:text-zinc-700"
                  ]}
                  stroke-width="4"
                  stroke-dasharray="565.48"
                  stroke-dashoffset={if @status == :complete, do: 0, else: 565.48}
                  stroke-linecap="round"
                  fill="transparent"
                  r="90"
                  cx="96"
                  cy="96"
                />
              </svg>

              <%!-- Fingerprint Icon --%>
              <div class="absolute inset-0 flex items-center justify-center">
                <div class={[
                  "w-32 h-32 rounded-full flex items-center justify-center transition-all duration-500",
                  @status == :scanning && "bg-indigo-500/10 scale-110",
                  @status == :complete && "bg-emerald-500/10 scale-110",
                  @status == :error && "bg-red-500/10",
                  @status == :idle && "bg-zinc-50 dark:bg-zinc-800 group-hover:bg-indigo-500/5"
                ]}>
                  <.icon
                    name="hero-finger-print"
                    class={[
                      "w-20 h-20 transition-colors duration-500",
                      @status == :complete && "text-emerald-500",
                      @status == :scanning && "text-indigo-500 pulse-soft",
                      @status == :error && "text-red-400",
                      @status == :idle && "text-zinc-400 dark:text-zinc-600 group-hover:text-indigo-400"
                    ]
                    |> Enum.filter(& &1)
                    |> Enum.join(" ")}
                  />
                </div>
              </div>
            </div>

            <div class="mt-8 space-y-2">
              <h3 class={[
                "text-lg font-semibold tracking-tight transition-colors duration-500",
                @status == :complete && "text-emerald-500",
                @status == :scanning && "text-indigo-500",
                @status == :error && "text-red-500",
                @status == :idle && "text-zinc-900 dark:text-zinc-100"
              ]}>
                <%= case @status do %>
                  <% :idle -> %> Scan Fingerprint
                  <% :scanning -> %> Verifying Identity...
                  <% :complete -> %> Identity Confirmed
                  <% :error -> %> Authentication Failed
                <% end %>
              </h3>

              <p class="text-sm text-zinc-500 dark:text-zinc-400 max-w-[280px] mx-auto leading-relaxed">
                <%= case @status do %>
                  <% :idle -> %> Place your enrolled finger on the sensor to authenticate.
                  <% :scanning -> %> Hold still — verifying your biometric signature.
                  <% :complete -> %> Redirecting you now...
                  <% :error -> %> {@error}
                <% end %>
              </p>
            </div>

            <%= if @status == :idle do %>
              <.button
                phx-click={JS.push("biometric_login_start") |> JS.dispatch("nx:biometric-login-start", to: "#login-trigger")}
                class="mt-10 px-8 py-3 bg-indigo-600 hover:bg-indigo-700 text-white rounded-full font-bold shadow-lg shadow-indigo-500/20 active:scale-95 transition-all"
              >
                Authenticate
              </.button>
            <% end %>

            <%= if @status == :error do %>
              <.button
                phx-click="retry"
                class="mt-10 px-8 py-3 bg-zinc-600 hover:bg-zinc-700 text-white rounded-full font-bold active:scale-95 transition-all"
              >
                Try Again
              </.button>
            <% end %>
          </div>
        </div>
      </div>
    </div>
    """
  end

  # ── Event Handlers ────────────────────────────────────────────────────────

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
        {:noreply, assign(socket, status: :error, error: "Could not initiate authentication. Please try again.")}
    end
  end

  @impl true
  def handle_event("login_verify", params, socket) do
    challenge_id = socket.assigns.challenge_id

    with {:ok, raw_id} <- decode_raw_id(params["rawId"]),
         user when not is_nil(user) <- GetUserByCredentialId.execute(raw_id),
         {:ok, cose_key} <- decode_cose_key(user.cose_key),
         {:ok, _auth} <- WebAuthn.verify_authentication(params, challenge_id, [{raw_id, cose_key}]),
         session_id <- Uniq.UUID.uuid7(),
         :ok <- dispatch_start_session(session_id, user, params) do
      auth_token = Phoenix.Token.sign(NexusWeb.Endpoint, "session_auth", session_id)

      {:noreply,
       socket
       |> assign(:status, :complete)
       |> push_navigate(to: "/auth/finalise?token=#{auth_token}")}
    else
      nil ->
        {:noreply,
         assign(socket,
           status: :error,
           error: "No registered credential found. Please contact your administrator."
         )}

      {:error, reason} ->
        Logger.error("[LoginUI] Biometric verification failed: #{inspect(reason)}")
        {:noreply, assign(socket, status: :error, error: format_error(reason))}
    end
  end

  @impl true
  def handle_event("biometric_error", %{"reason" => reason}, socket) do
    Logger.warning("[LoginUI] Client-side biometric error: #{reason}")

    message =
      if String.contains?(reason, "focus") do
        "Security focus lost. Click the fingerprint scanner directly and try again."
      else
        "Hardware authentication failed: #{reason}"
      end

    {:noreply, assign(socket, status: :error, error: message)}
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

  defp decode_raw_id(nil), do: {:error, :missing_credential}

  defp decode_raw_id(raw_id) do
    try do
      {:ok, Base.decode64!(raw_id)}
    rescue
      _ -> {:error, :invalid_credential_encoding}
    end
  end

  defp decode_cose_key(nil), do: {:error, :no_enrolled_credential}

  defp decode_cose_key(encoded) do
    try do
      key = encoded |> Base.decode64!(padding: false) |> :erlang.binary_to_term([:safe])
      {:ok, key}
    rescue
      _ -> {:error, :invalid_cose_key}
    end
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
