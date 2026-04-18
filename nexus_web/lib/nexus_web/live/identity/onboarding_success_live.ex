defmodule NexusWeb.Identity.OnboardingSuccessLive do
  use NexusWeb, :live_view

  require Logger

  @impl true
  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="mx-auto max-w-md mt-32">
      <div class="relative p-10 overflow-hidden bg-white dark:bg-zinc-900 border border-zinc-200 dark:border-zinc-800 rounded-3xl shadow-2xl">
        <%!-- World-Class Background Gradients --%>
        <div class="absolute inset-0 bg-[radial-gradient(circle_at_top_right,rgba(16,185,129,0.1),transparent)] pointer-events-none" />
        <div class="absolute inset-0 bg-[radial-gradient(circle_at_bottom_left,rgba(79,70,229,0.05),transparent)] pointer-events-none" />

        <div class="relative z-10 text-center">
          <%!-- Success Icon with Outer Glow --%>
          <div class="mb-8 relative inline-block">
            <div class="absolute inset-0 bg-emerald-500/20 blur-2xl rounded-full" />
            <div class="relative bg-emerald-500/10 p-4 rounded-full border border-emerald-500/20">
              <.icon name="hero-check-badge" class="w-16 h-16 text-emerald-500" />
            </div>
            <%!-- Micro-interaction Sparkles --%>
            <div class="absolute -top-1 -right-1">
              <.icon name="hero-sparkles" class="w-6 h-6 text-indigo-400 animate-pulse" />
            </div>
          </div>

          <.header class="space-y-4">
            <span class="inline-flex items-center gap-1.5 px-3 py-1 rounded-full bg-indigo-50 dark:bg-indigo-950/30 text-[10px] font-bold tracking-widest text-indigo-600 dark:text-indigo-400 uppercase border border-indigo-100 dark:border-indigo-900/50">
              Hardware Root of Trust established
            </span>
            <div class="text-3xl font-extrabold tracking-tight text-zinc-900 dark:text-zinc-100">
              Identity Sovereignly Anchored
            </div>
            <:subtitle>
              Your biometric profile has been successfully cryptographically bound to this hardware node.
            </:subtitle>
          </.header>

          <div class="mt-10 p-6 bg-zinc-50 dark:bg-zinc-800/50 rounded-2xl border border-zinc-100 dark:border-zinc-800 text-left space-y-4">
            <div class="flex items-center gap-3">
              <div class="w-8 h-8 rounded-lg bg-emerald-500/10 flex items-center justify-center text-emerald-500">
                <.icon name="hero-shield-check" class="w-5 h-5" />
              </div>
              <div class="text-sm">
                <p class="font-bold text-zinc-900 dark:text-zinc-100">Hardware Bound</p>
                <p class="text-zinc-500 dark:text-zinc-400 text-xs">
                  Credential verified and signed by platform TPM.
                </p>
              </div>
            </div>
            <div class="flex items-center gap-3">
              <div class="w-8 h-8 rounded-lg bg-indigo-500/10 flex items-center justify-center text-indigo-500">
                <.icon name="hero-finger-print" class="w-5 h-5" />
              </div>
              <div class="text-sm">
                <p class="font-bold text-zinc-900 dark:text-zinc-100">Biometric Verification</p>
                <p class="text-zinc-500 dark:text-zinc-400 text-xs">
                  TouchID/FaceID configured for instant access.
                </p>
              </div>
            </div>
          </div>

          <.button
            navigate={~p"/vaults"}
            class="mt-12 w-full py-4 bg-zinc-900 dark:bg-indigo-600 hover:bg-zinc-800 dark:hover:bg-indigo-700 text-white rounded-2xl font-bold shadow-xl shadow-indigo-500/10 transition-all hover:-translate-y-0.5"
          >
            Enter Network Dashboard
          </.button>

          <p class="mt-6 text-[10px] text-zinc-400 dark:text-zinc-500 font-medium">
            Nexus Poncho Identity Service v1.0.3 • Sovereign Flow
          </p>
        </div>
      </div>
    </div>
    """
  end
end
