defmodule NexusWeb.Marketing.RequestAccessLive do
  use NexusWeb, :live_view

  alias Nexus.App
  alias Nexus.Marketing.Commands.SubmitAccessRequest
  alias Nexus.Marketing.Projections.AccessRequest
  alias Nexus.Shared.Tracing

  require OpenTelemetry.Tracer

  @steps [
    %{id: 1, title: "IDENTITY_ANCHOR", label: "Provide personal identity credentials"},
    %{id: 2, title: "INSTITUTIONAL_MAPPING", label: "Define institutional affiliation"},
    %{id: 3, title: "OPERATIONAL_SCOPE", label: "Analyze treasury requirements"}
  ]

  @impl true
  def mount(_params, _session, socket) do
    request_id = Uniq.UUID.uuid7()
    changeset = AccessRequest.changeset(%AccessRequest{}, %{})

    {:ok,
     socket
     |> assign(
       page_title: "Institutional Authorization",
       request_id: request_id,
       current_step: 1,
       steps: @steps,
       form: to_form(changeset),
       submitted: false
     )}
  end

  @impl true
  def handle_event("next_step", _params, socket) do
    current_step = socket.assigns.current_step

    # Advance and push event for animations
    if current_step < length(@steps) do
      {:noreply,
       socket
       |> assign(current_step: current_step + 1)
       |> push_event("step_changed", %{step: current_step + 1})}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("prev_step", _params, socket) do
    current_step = socket.assigns.current_step

    if current_step > 1 do
      {:noreply,
       socket
       |> assign(current_step: current_step - 1)
       |> push_event("step_changed", %{step: current_step - 1})}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("validate", %{"access_request" => params}, socket) do
    changeset =
      %AccessRequest{}
      |> AccessRequest.changeset(params)
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, form: to_form(changeset))}
  end

  @impl true
  def handle_event("save", %{"access_request" => params}, socket) do
    changeset = AccessRequest.changeset(%AccessRequest{}, params)

    if changeset.valid? do
      command = %SubmitAccessRequest{
        request_id: socket.assigns.request_id,
        email: params["email"],
        name: params["name"],
        organization: params["organization"],
        job_title: params["job_title"],
        treasury_volume: params["treasury_volume"],
        subsidiaries: params["subsidiaries"],
        message: params["message"]
      }

      tracing_metadata = Tracing.inject_context(%{})

      OpenTelemetry.Tracer.with_span "Marketing.SubmitAccessRequest" do
        case App.dispatch(command,
               metadata: Map.put(tracing_metadata, "idempotency_key", socket.assigns.request_id)
             ) do
          :ok ->
            {:noreply, assign(socket, submitted: true)}

          {:error, :access_request_already_submitted} ->
            {:noreply, assign(socket, submitted: true)}

          {:error, _reason} ->
            {:noreply, put_flash(socket, :error, "Submission failed. Please try again.")}
        end
      end
    else
      {:noreply, assign(socket, form: to_form(changeset))}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <section class="min-h-screen pt-32 pb-24 px-6 relative overflow-hidden bg-[#030303]">
      <%!-- Sovereign Glow --%>
      <div class="absolute inset-0 bg-[radial-gradient(ellipse_80%_50%_at_50%_-20%,rgba(52,211,153,0.05),transparent)] pointer-events-none">
      </div>

      <div class="max-w-6xl mx-auto relative z-10">
        <%!-- Page header --%>
        <div class="text-center mb-16">
          <div class="inline-flex items-center gap-3 px-0 mb-6 group">
            <span class="w-1 h-1 rounded-full bg-emerald-400"></span>
            <span class="font-mono text-[10px] tracking-[0.4em] text-emerald-400/60 uppercase">
              Access Authorization
            </span>
          </div>
          <h1 class="font-serif text-5xl md:text-7xl font-black text-white leading-[1.1] mb-6 tracking-tight">
            Initialize Institutional <span class="emerald-glint">Deployment.</span>
          </h1>
          <p class="text-zinc-500 text-lg max-w-2xl mx-auto font-medium">
            Equinox is by invitation. Complete the multi-step anchoring protocol to begin your institutional journey.
          </p>
        </div>

        <div
          class="grid lg:grid-cols-5 gap-12 items-start"
          id="access-protocol-container"
          phx-hook="AccessProtocol"
        >
          <%!-- Left column: protocol progress --%>
          <div class="lg:col-span-2 space-y-10">
            <div>
              <p class="font-mono text-[10px] tracking-[0.3em] text-zinc-600 uppercase mb-8">
                Deployment Protocol
              </p>
              <div class="space-y-6">
                <%= for step <- @steps do %>
                  <div class={[
                    "protocol-step relative flex gap-6 transition-all duration-500",
                    @current_step < step.id && "opacity-30 grayscale",
                    @current_step == step.id && "opacity-100",
                    @current_step > step.id && "opacity-60"
                  ]}>
                    <div class="flex flex-col items-center">
                      <div class={[
                        "w-10 h-10 rounded-full border flex items-center justify-center transition-all duration-500",
                        if(@current_step >= step.id,
                          do:
                            "border-emerald-400/50 bg-emerald-400/10 text-emerald-400 shadow-[0_0_20px_rgba(52,211,153,0.1)]",
                          else: "border-white/10 text-zinc-700"
                        )
                      ]}>
                        <%= if @current_step > step.id do %>
                          <.icon name="hero-check-mini" class="w-5 h-5" />
                        <% else %>
                          <span class="font-mono text-xs font-bold">{step.id}</span>
                        <% end %>
                      </div>
                      <%= if step.id < 3 do %>
                        <div class={[
                          "w-px h-12 my-2 transition-all duration-500",
                          if(@current_step > step.id, do: "bg-emerald-400/40", else: "bg-white/5")
                        ]}>
                        </div>
                      <% end %>
                    </div>
                    <div class="pt-2">
                      <p class={[
                        "font-mono text-[10px] tracking-[0.2em] uppercase transition-colors duration-500",
                        if(@current_step == step.id, do: "text-emerald-400", else: "text-zinc-600")
                      ]}>
                        {step.title}
                      </p>
                      <p class="text-zinc-500 text-xs mt-1 font-medium italic">
                        {step.label}
                      </p>
                    </div>
                  </div>
                <% end %>
              </div>
            </div>

            <%!-- Trust note --%>
            <div class="pt-10 border-t border-white/5">
              <p class="font-mono text-[9px] tracking-[0.2em] text-zinc-700 uppercase mb-3">
                Institutional Privacy Guarantee
              </p>
              <p class="text-zinc-600 text-[11px] leading-relaxed italic">
                Your credentials are used solely to evaluate access eligibility. Equinox maintains strict ephemeral data life-cycles for all authorization requests.
              </p>
            </div>
          </div>

          <%!-- Right column: active step form --%>
          <div class="lg:col-span-3">
            <%= if @submitted do %>
              <div class="prestige-card rounded-[2.5rem] p-12 text-center animate-in fade-in zoom-in duration-700">
                <div class="w-20 h-20 rounded-full bg-emerald-400/10 border border-emerald-400/20 flex items-center justify-center mx-auto mb-8 shadow-[0_0_50px_rgba(52,211,153,0.15)]">
                  <.icon name="hero-check-circle" class="w-10 h-10 text-emerald-400" />
                </div>
                <p class="font-mono text-[10px] tracking-[0.3em] text-emerald-400/60 uppercase mb-4">
                  Sovereign Request Logged
                </p>
                <h2 class="font-serif text-4xl font-black text-white mb-6 tracking-tight leading-tight">
                  Awaiting Node <span class="emerald-glint">Authorization.</span>
                </h2>
                <p class="text-zinc-500 max-w-sm mx-auto text-sm leading-relaxed font-medium">
                  Our treasury onboarding team is currently validating your institutional profile. Authorization typically completes within 48 business hours.
                </p>
                <div class="mt-12 pt-8 border-t border-white/5">
                  <.link
                    navigate={~p"/"}
                    class="font-mono text-[10px] tracking-[0.2em] text-zinc-500 hover:text-emerald-400 uppercase transition-all duration-300"
                  >
                    ← Return to Platform
                  </.link>
                </div>
              </div>
            <% else %>
              <div class="prestige-card rounded-[2.5rem] p-10 md:p-12 min-h-[500px] flex flex-col">
                <.form
                  for={@form}
                  id="request-access-form"
                  phx-change="validate"
                  phx-submit="save"
                  class="flex-1 flex flex-col"
                >
                  <div
                    :if={@current_step == 1}
                    data-step="1"
                    class="space-y-8"
                  >
                    <div class="mb-10">
                      <p class="font-mono text-[10px] tracking-[0.4em] text-emerald-400/60 uppercase mb-3">
                        Phase I: Identity Anchor
                      </p>
                      <h3 class="text-2xl font-serif font-black text-white tracking-tight">
                        Establishing Presence.
                      </h3>
                    </div>

                    <div class="space-y-6">
                      <div>
                        <label class="block font-mono text-[9px] tracking-[0.25em] text-zinc-600 uppercase mb-3">
                          Entity Name / Full Name
                        </label>
                        <.input
                          field={@form[:name]}
                          type="text"
                          placeholder="E.G. JANE THORNTON"
                          class="w-full bg-white/5 border border-white/5 rounded-xl px-6 py-5 text-white placeholder-white/10 text-sm font-mono focus:outline-none focus:border-emerald-400/40 focus:bg-white/[0.08] transition-all duration-300"
                        />
                      </div>
                      <div>
                        <label class="block font-mono text-[9px] tracking-[0.25em] text-zinc-600 uppercase mb-3">
                          Identity Anchor / Work Email
                        </label>
                        <.input
                          field={@form[:email]}
                          type="email"
                          placeholder="JANE@INSTITUTION.COM"
                          class="w-full bg-white/5 border border-white/5 rounded-xl px-6 py-5 text-white placeholder-white/10 text-sm font-mono focus:outline-none focus:border-emerald-400/40 focus:bg-white/[0.08] transition-all duration-300"
                        />
                      </div>
                    </div>
                  </div>

                  <div
                    :if={@current_step == 2}
                    data-step="2"
                    class="space-y-8"
                  >
                    <div class="mb-10">
                      <p class="font-mono text-[10px] tracking-[0.4em] text-emerald-400/60 uppercase mb-3">
                        Phase II: Institutional Mapping
                      </p>
                      <h3 class="text-2xl font-serif font-black text-white tracking-tight">
                        Domain Affiliation.
                      </h3>
                    </div>

                    <div class="space-y-6">
                      <div>
                        <label class="block font-mono text-[9px] tracking-[0.25em] text-zinc-600 uppercase mb-3">
                          Institutional Domain / Organisation
                        </label>
                        <.input
                          field={@form[:organization]}
                          type="text"
                          placeholder="E.G. ACME HOLDINGS LTD."
                          class="w-full bg-white/5 border border-white/5 rounded-xl px-6 py-5 text-white placeholder-white/10 text-sm font-mono focus:outline-none focus:border-emerald-400/40 focus:bg-white/[0.08] transition-all duration-300"
                        />
                      </div>
                      <div>
                        <label class="block font-mono text-[9px] tracking-[0.25em] text-zinc-600 uppercase mb-3">
                          Operational Role / Job Title
                        </label>
                        <.input
                          field={@form[:job_title]}
                          type="text"
                          placeholder="E.G. GROUP TREASURER"
                          class="w-full bg-white/5 border border-white/5 rounded-xl px-6 py-5 text-white placeholder-white/10 text-sm font-mono focus:outline-none focus:border-emerald-400/40 focus:bg-white/[0.08] transition-all duration-300"
                        />
                      </div>
                    </div>
                  </div>

                  <div
                    :if={@current_step == 3}
                    data-step="3"
                    class="space-y-8"
                  >
                    <div class="mb-10">
                      <p class="font-mono text-[10px] tracking-[0.4em] text-emerald-400/60 uppercase mb-3">
                        Phase III: Operational Scope
                      </p>
                      <h3 class="text-2xl font-serif font-black text-white tracking-tight">
                        Scale Analysis.
                      </h3>
                    </div>

                    <div class="space-y-6">
                      <div class="grid grid-cols-2 gap-6">
                        <div>
                          <label class="block font-mono text-[9px] tracking-[0.25em] text-zinc-600 uppercase mb-3">
                            Treasury Volume
                          </label>
                          <div class="relative">
                            <.input
                              field={@form[:treasury_volume]}
                              type="select"
                              options={[
                                {"SELECT VOLUME...", ""},
                                {"< $10M", "lt_10m"},
                                {"$10M – $100M", "10m_100m"},
                                {"$100M – $500M", "100m_500m"},
                                {"$500M – $1B", "500m_1b"},
                                {"> $1B", "gt_1b"}
                              ]}
                              class="w-full bg-white/5 border border-white/5 rounded-xl px-6 py-5 text-white text-sm font-mono focus:outline-none focus:border-emerald-400/40 focus:bg-white/[0.08] transition-all appearance-none cursor-pointer"
                            />
                            <div class="pointer-events-none absolute inset-y-0 right-5 flex items-center">
                              <.icon name="hero-chevron-down" class="w-4 h-4 text-white/20" />
                            </div>
                          </div>
                        </div>
                        <div>
                          <label class="block font-mono text-[9px] tracking-[0.25em] text-zinc-600 uppercase mb-3">
                            Subsidiaries
                          </label>
                          <div class="relative">
                            <.input
                              field={@form[:subsidiaries]}
                              type="select"
                              options={[
                                {"SELECT COUNT...", ""},
                                {"1 – 5", "1_5"},
                                {"6 – 20", "6_20"},
                                {"21 – 50", "21_50"},
                                {"51 – 100", "51_100"},
                                {"100+", "100_plus"}
                              ]}
                              class="w-full bg-white/5 border border-white/5 rounded-xl px-6 py-5 text-white text-sm font-mono focus:outline-none focus:border-emerald-400/40 focus:bg-white/[0.08] transition-all appearance-none cursor-pointer"
                            />
                            <div class="pointer-events-none absolute inset-y-0 right-5 flex items-center">
                              <.icon name="hero-chevron-down" class="w-4 h-4 text-white/20" />
                            </div>
                          </div>
                        </div>
                      </div>

                      <div>
                        <label class="block font-mono text-[9px] tracking-[0.25em] text-zinc-600 uppercase mb-3">
                          Deployment Notes (Optional)
                        </label>
                        <.input
                          field={@form[:message]}
                          type="textarea"
                          placeholder="PAIN POINTS OR TIMELINE..."
                          rows="3"
                          class="w-full bg-white/5 border border-white/5 rounded-xl px-6 py-5 text-white placeholder-white/10 text-sm font-mono focus:outline-none focus:border-emerald-400/40 focus:bg-white/[0.08] transition-all resize-none"
                        />
                      </div>
                    </div>
                  </div>

                  <%!-- Navigation Controls --%>
                  <div class="mt-auto pt-12 flex items-center justify-between gap-6">
                    <button
                      :if={@current_step > 1}
                      type="button"
                      phx-click="prev_step"
                      class="px-8 py-5 border border-white/10 rounded-xl text-[10px] font-bold text-zinc-400 uppercase tracking-widest hover:bg-white/5 transition-all"
                    >
                      Back
                    </button>
                    <div :if={@current_step == 1} class="flex-1"></div>

                    <button
                      :if={@current_step < 3}
                      type="button"
                      phx-click="next_step"
                      class="flex-1 py-5 bg-white/5 border border-white/10 text-white rounded-xl text-[10px] font-black uppercase tracking-[0.3em] flex items-center justify-center gap-3 hover:bg-white/10 transition-all group"
                    >
                      <span>Continue Protocol</span>
                      <.icon
                        name="hero-arrow-right"
                        class="w-4 h-4 text-emerald-400 group-hover:translate-x-1 transition-transform"
                      />
                    </button>

                    <button
                      :if={@current_step == 3}
                      type="submit"
                      class="cta-primary flex-1 py-5 bg-emerald-400 text-black rounded-xl text-[10px] font-black uppercase tracking-[0.3em] flex items-center justify-center gap-3 shadow-[0_10px_30px_rgba(52,211,153,0.1)]"
                    >
                      <span class="relative z-10 flex items-center gap-3">
                        Submit Authorization
                        <span class="arrow-wrap">
                          <.icon name="hero-arrow-up-right" class="w-4 h-4 arrow-icon" />
                          <.icon name="hero-arrow-up-right" class="w-4 h-4 arrow-clone" />
                        </span>
                      </span>
                    </button>
                  </div>

                  <p class="text-center text-zinc-700 text-[9px] font-mono mt-8 uppercase tracking-[0.2em]">
                    Secure handshake in progress · Node verification active
                  </p>
                </.form>
              </div>
            <% end %>
          </div>
        </div>
      </div>
    </section>
    """
  end
end
