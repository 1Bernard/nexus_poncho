defmodule NexusWeb.Identity.OnboardingSuccessLive do
  use NexusWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-[#010101] flex items-center justify-center px-4 relative">
      <div class="absolute inset-0 bg-grid-elite pointer-events-none"></div>

      <div class="w-full max-w-[460px] prestige-card rounded-[2.5rem] relative overflow-hidden">
        <%!-- Top accent bar --%>
        <div class="flex gap-2 p-8 pb-0">
          <span class="h-1 w-10 rounded-full bg-emerald-400 shadow-[0_0_15px_rgba(52,211,153,0.9)]">
          </span>
          <span class="h-1 w-10 rounded-full bg-emerald-400 shadow-[0_0_15px_rgba(52,211,153,0.9)]">
          </span>
        </div>

        <div class="px-10 pb-10 pt-8 flex flex-col items-center text-center">
          <%!-- Icon --%>
          <div class="w-20 h-20 rounded-2xl bg-emerald-400/10 flex items-center justify-center border border-emerald-400/20 mb-6 relative">
            <.icon name="hero-check-badge" class="w-10 h-10 text-emerald-400" />
            <div class="absolute inset-0 rounded-2xl shadow-[0_0_30px_rgba(52,211,153,0.15)]"></div>
          </div>

          <h1 class="text-3xl font-serif italic font-black tracking-tight text-white mb-2">
            Identity<br /><span class="emerald-glint">Anchored.</span>
          </h1>

          <p class="text-[9px] font-mono text-zinc-500 uppercase tracking-[0.2em] mb-10">
            Hardware root of trust established
          </p>

          <%!-- Status rows --%>
          <div class="w-full space-y-2 mb-10 text-left">
            <div class="flex items-center gap-4 p-4 bg-white/[0.03] border border-white/[0.06] rounded-xl">
              <div class="w-8 h-8 rounded-lg bg-emerald-400/10 flex items-center justify-center shrink-0">
                <.icon name="hero-shield-check" class="w-4 h-4 text-emerald-400" />
              </div>
              <div>
                <p class="text-[10px] font-mono font-bold text-white/80 uppercase tracking-widest">
                  Hardware Bound
                </p>
                <p class="text-[9px] font-mono text-zinc-600 mt-0.5">
                  Credential signed by platform TPM
                </p>
              </div>
              <span class="ml-auto text-[9px] font-mono text-emerald-400 uppercase tracking-widest">
                OK
              </span>
            </div>

            <div class="flex items-center gap-4 p-4 bg-white/[0.03] border border-white/[0.06] rounded-xl">
              <div class="w-8 h-8 rounded-lg bg-emerald-400/10 flex items-center justify-center shrink-0">
                <.icon name="hero-finger-print" class="w-4 h-4 text-emerald-400" />
              </div>
              <div>
                <p class="text-[10px] font-mono font-bold text-white/80 uppercase tracking-widest">
                  Biometric Enrolled
                </p>
                <p class="text-[9px] font-mono text-zinc-600 mt-0.5">
                  TouchID / FaceID configured
                </p>
              </div>
              <span class="ml-auto text-[9px] font-mono text-emerald-400 uppercase tracking-widest">
                OK
              </span>
            </div>

            <div class="flex items-center gap-4 p-4 bg-white/[0.03] border border-white/[0.06] rounded-xl">
              <div class="w-8 h-8 rounded-lg bg-emerald-400/10 flex items-center justify-center shrink-0">
                <.icon name="hero-key" class="w-4 h-4 text-emerald-400" />
              </div>
              <div>
                <p class="text-[10px] font-mono font-bold text-white/80 uppercase tracking-widest">
                  256-bit WebAuthn
                </p>
                <p class="text-[9px] font-mono text-zinc-600 mt-0.5">
                  Passkey bound to this device
                </p>
              </div>
              <span class="ml-auto text-[9px] font-mono text-emerald-400 uppercase tracking-widest">
                OK
              </span>
            </div>
          </div>

          <.link
            navigate={~p"/vaults"}
            class="cta-primary w-full py-5 bg-emerald-400 text-black rounded-full text-[10px] font-black uppercase tracking-[0.3em] flex items-center justify-center gap-3 shadow-[0_10px_30px_rgba(52,211,153,0.1)]"
          >
            <.icon name="hero-arrow-right" class="w-4 h-4" />
            <span>Enter the Network</span>
          </.link>
        </div>

        <div class="border-t border-white/5 px-7 py-5 flex items-center justify-between text-white/30 text-[8px] font-mono tracking-widest">
          <span>EQUINOX · IDENTITY ANCHOR</span>
          <span>256-BIT WEBAUTHN</span>
        </div>
      </div>
    </div>
    """
  end
end
