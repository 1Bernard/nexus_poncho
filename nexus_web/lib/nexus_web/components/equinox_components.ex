defmodule NexusWeb.EquinoxComponents do
  @moduledoc """
  Equinox Design System — component library for authenticated pages.

  Design language:
  - Dark surfaces: bg-white/5, bg-zinc-950
  - Accent: emerald-400 (#34d399)
  - Typography: JetBrains Mono for labels/code, Inter for body
  - Inputs: dark glass with emerald focus rings
  - Errors: red-400 with mono uppercase label
  """
  use Phoenix.Component

  import NexusWeb.CoreComponents, only: [icon: 1, translate_error: 1]

  alias Phoenix.HTML.Form

  # ── prestige_card ─────────────────────────────────────────────────────────────
  # The signature high-end container for forms, login, and dashboard sections.

  attr :class, :string, default: nil
  slot :inner_block, required: true

  def prestige_card(assigns) do
    ~H"""
    <div class={["prestige-card rounded-[2.5rem] relative overflow-hidden", @class]}>
      {render_slot(@inner_block)}
    </div>
    """
  end

  # ── eq_input ──────────────────────────────────────────────────────────────────
  # Text, email, number, password, date, etc.

  attr :id, :any, default: nil
  attr :name, :any
  attr :label, :string, default: nil
  attr :value, :any

  attr :type, :string,
    default: "text",
    values:
      ~w(color date datetime-local email file month number password search tel text time url week)

  attr :field, Phoenix.HTML.FormField, doc: "a form field struct, e.g. @form[:email]"
  attr :errors, :list, default: []
  attr :class, :string, default: nil

  attr :rest, :global,
    include: ~w(accept autocomplete capture disabled form list max maxlength min minlength
                pattern placeholder readonly required size step)

  def eq_input(%{field: %Phoenix.HTML.FormField{} = field} = assigns) do
    errors = if Phoenix.Component.used_input?(field), do: field.errors, else: []

    assigns
    |> assign(field: nil, id: assigns.id || field.id)
    |> assign(:errors, Enum.map(errors, &translate_error(&1)))
    |> assign_new(:name, fn -> field.name end)
    |> assign_new(:value, fn -> field.value end)
    |> eq_input()
  end

  def eq_input(assigns) do
    ~H"""
    <div>
      <label
        :if={@label}
        for={@id}
        class="block font-mono text-[9px] tracking-[0.25em] text-zinc-600 uppercase mb-3"
      >
        {@label}
      </label>
      <input
        type={@type}
        name={@name}
        id={@id}
        value={Form.normalize_value(@type, @value)}
        class={[
          "w-full bg-white/5 border rounded-xl px-5 py-4",
          "text-white placeholder-white/20 text-sm font-mono",
          "focus:outline-none focus:bg-white/[0.08] transition-all duration-300",
          @errors == [] && "border-white/5 focus:border-emerald-400/40",
          @errors != [] && "border-red-500/40 focus:border-red-500/60",
          @class
        ]}
        {@rest}
      />
      <.eq_field_error :for={msg <- @errors}>{msg}</.eq_field_error>
    </div>
    """
  end

  # ── eq_select ─────────────────────────────────────────────────────────────────

  attr :id, :any, default: nil
  attr :name, :any
  attr :label, :string, default: nil
  attr :value, :any
  attr :field, Phoenix.HTML.FormField
  attr :errors, :list, default: []
  attr :prompt, :string, default: nil
  attr :options, :list, required: true
  attr :multiple, :boolean, default: false
  attr :class, :string, default: nil
  attr :rest, :global, include: ~w(disabled form required)

  def eq_select(%{field: %Phoenix.HTML.FormField{} = field} = assigns) do
    errors = if Phoenix.Component.used_input?(field), do: field.errors, else: []

    assigns
    |> assign(field: nil, id: assigns.id || field.id)
    |> assign(:errors, Enum.map(errors, &translate_error(&1)))
    |> assign_new(:name, fn -> field.name end)
    |> assign_new(:value, fn -> field.value end)
    |> eq_select()
  end

  def eq_select(assigns) do
    ~H"""
    <div>
      <label
        :if={@label}
        for={@id}
        class="block font-mono text-[9px] tracking-[0.25em] text-zinc-600 uppercase mb-3"
      >
        {@label}
      </label>
      <div class="relative">
        <select
          id={@id}
          name={@name}
          multiple={@multiple}
          class={[
            "w-full bg-white/5 border rounded-xl px-5 py-4",
            "text-white text-sm font-mono",
            "focus:outline-none focus:bg-white/[0.08] transition-all duration-300",
            "appearance-none cursor-pointer",
            @errors == [] && "border-white/5 focus:border-emerald-400/40",
            @errors != [] && "border-red-500/40 focus:border-red-500/60",
            @class
          ]}
          {@rest}
        >
          <option :if={@prompt} value="">{@prompt}</option>
          {Form.options_for_select(@options, @value)}
        </select>
        <div class="pointer-events-none absolute inset-y-0 right-5 flex items-center">
          <.icon name="hero-chevron-down-mini" class="size-4 text-white/20" />
        </div>
      </div>
      <.eq_field_error :for={msg <- @errors}>{msg}</.eq_field_error>
    </div>
    """
  end

  # ── eq_textarea ───────────────────────────────────────────────────────────────

  attr :id, :any, default: nil
  attr :name, :any
  attr :label, :string, default: nil
  attr :value, :any
  attr :field, Phoenix.HTML.FormField
  attr :errors, :list, default: []
  attr :class, :string, default: nil

  attr :rest, :global,
    include: ~w(cols disabled form maxlength minlength placeholder readonly required rows)

  def eq_textarea(%{field: %Phoenix.HTML.FormField{} = field} = assigns) do
    errors = if Phoenix.Component.used_input?(field), do: field.errors, else: []

    assigns
    |> assign(field: nil, id: assigns.id || field.id)
    |> assign(:errors, Enum.map(errors, &translate_error(&1)))
    |> assign_new(:name, fn -> field.name end)
    |> assign_new(:value, fn -> field.value end)
    |> eq_textarea()
  end

  def eq_textarea(assigns) do
    ~H"""
    <div>
      <label
        :if={@label}
        for={@id}
        class="block font-mono text-[9px] tracking-[0.25em] text-zinc-600 uppercase mb-3"
      >
        {@label}
      </label>
      <textarea
        id={@id}
        name={@name}
        class={[
          "w-full bg-white/5 border rounded-xl px-5 py-4",
          "text-white placeholder-white/20 text-sm font-mono",
          "focus:outline-none focus:bg-white/[0.08] transition-all duration-300 resize-none",
          @errors == [] && "border-white/5 focus:border-emerald-400/40",
          @errors != [] && "border-red-500/40 focus:border-red-500/60",
          @class
        ]}
        {@rest}
      >{Form.normalize_value("textarea", @value)}</textarea>
      <.eq_field_error :for={msg <- @errors}>{msg}</.eq_field_error>
    </div>
    """
  end

  # ── eq_checkbox ───────────────────────────────────────────────────────────────

  attr :id, :any, default: nil
  attr :name, :any
  attr :label, :string, default: nil
  attr :checked, :boolean, default: false
  attr :field, Phoenix.HTML.FormField
  attr :errors, :list, default: []
  attr :rest, :global, include: ~w(disabled form required)

  def eq_checkbox(%{field: %Phoenix.HTML.FormField{} = field} = assigns) do
    errors = if Phoenix.Component.used_input?(field), do: field.errors, else: []

    assigns
    |> assign(field: nil, id: assigns.id || field.id)
    |> assign(:errors, Enum.map(errors, &translate_error(&1)))
    |> assign_new(:name, fn -> field.name end)
    |> assign_new(:checked, fn -> Form.normalize_value("checkbox", field.value) end)
    |> eq_checkbox()
  end

  def eq_checkbox(assigns) do
    ~H"""
    <div>
      <label class="flex items-center gap-4 cursor-pointer group">
        <input type="hidden" name={@name} value="false" />
        <div class="relative">
          <input
            type="checkbox"
            id={@id}
            name={@name}
            value="true"
            checked={@checked}
            class="sr-only peer"
            {@rest}
          />
          <div class={[
            "w-5 h-5 border rounded flex items-center justify-center transition-all duration-200",
            "peer-checked:bg-emerald-400 peer-checked:border-emerald-400",
            "peer-unchecked:bg-white/5",
            @errors == [] && "border-white/10",
            @errors != [] && "border-red-500/40"
          ]}>
            <.icon
              name="hero-check-mini"
              class="size-3 text-black opacity-0 peer-checked:opacity-100"
            />
          </div>
        </div>
        <span
          :if={@label}
          class="text-sm font-mono text-zinc-400 group-hover:text-white transition-colors"
        >
          {@label}
        </span>
      </label>
      <.eq_field_error :for={msg <- @errors}>{msg}</.eq_field_error>
    </div>
    """
  end

  # ── eq_form ───────────────────────────────────────────────────────────────────

  attr :for, :any, required: true
  attr :as, :any, default: nil
  attr :class, :string, default: nil

  attr :rest, :global,
    include: ~w(autocomplete name rel action enctype method novalidate target multipart)

  slot :actions
  slot :inner_block, required: true

  def eq_form(assigns) do
    ~H"""
    <.form :let={f} for={@for} as={@as} {@rest}>
      <div class={["space-y-6", @class]}>
        {render_slot(@inner_block, f)}
        <div :for={action <- @actions} class="pt-2">
          {render_slot(action, f)}
        </div>
      </div>
    </.form>
    """
  end

  # ── eq_button ─────────────────────────────────────────────────────────────────

  attr :variant, :string, values: ~w(primary secondary ghost danger outline), default: "primary"
  attr :full_width, :boolean, default: false
  attr :arrow, :boolean, default: false
  attr :class, :string, default: nil

  attr :rest, :global,
    include: ~w(navigate patch href method disabled type form phx-click phx-submit)

  slot :inner_block, required: true

  def eq_button(assigns) do
    variant_class =
      case assigns.variant do
        "primary" ->
          "cta-primary bg-emerald-400 text-black shadow-[0_0_20px_rgba(52,211,153,0.15)]"

        "secondary" ->
          "bg-white/5 border border-white/10 text-white hover:bg-white/10"

        "ghost" ->
          "text-emerald-400 hover:bg-emerald-400/5"

        "danger" ->
          "border border-red-500/30 text-red-400 hover:bg-red-500/10"

        "outline" ->
          "border border-white/10 text-zinc-400 hover:bg-white/5"
      end

    assigns =
      assign(assigns, :computed_class, [
        "inline-flex items-center justify-center gap-2",
        "px-8 py-5 rounded-xl",
        "text-[10px] font-black uppercase tracking-[0.3em]",
        "transition-all duration-300 disabled:opacity-40 disabled:cursor-not-allowed",
        variant_class,
        assigns.full_width && "w-full",
        assigns.class
      ])

    ~H"""
    <%= if @rest[:navigate] || @rest[:patch] || @rest[:href] do %>
      <.link class={@computed_class} {@rest}>
        <span class="relative z-10 flex items-center gap-3">
          {render_slot(@inner_block)}
          <span :if={@arrow} class="arrow-wrap">
            <.icon name="hero-arrow-up-right" class="w-4 h-4 arrow-icon" />
            <.icon name="hero-arrow-up-right" class="w-4 h-4 arrow-clone" />
          </span>
        </span>
      </.link>
    <% else %>
      <button class={@computed_class} {@rest}>
        <span class="relative z-10 flex items-center gap-3">
          {render_slot(@inner_block)}
          <span :if={@arrow} class="arrow-wrap">
            <.icon name="hero-arrow-up-right" class="w-4 h-4 arrow-icon" />
            <.icon name="hero-arrow-up-right" class="w-4 h-4 arrow-clone" />
          </span>
        </span>
      </button>
    <% end %>
    """
  end

  # ── eq_page_header ────────────────────────────────────────────────────────────

  attr :section, :string, required: true, doc: "e.g. 'Treasury'"
  attr :title, :string, required: true
  attr :subtitle, :string, default: nil
  slot :actions

  def eq_page_header(assigns) do
    ~H"""
    <div class="flex items-center justify-between mb-10">
      <div>
        <p class="tech-label text-emerald-400 mb-2">{@section}</p>
        <h1 class="text-2xl font-black uppercase tracking-tight text-white">{@title}</h1>
        <p :if={@subtitle} class="text-sm text-zinc-500 font-mono mt-1">{@subtitle}</p>
      </div>
      <div :if={@actions != []} class="flex items-center gap-3">
        {render_slot(@actions)}
      </div>
    </div>
    """
  end

  # ── eq_badge ──────────────────────────────────────────────────────────────────

  attr :status, :string, required: true
  attr :class, :string, default: nil

  def eq_badge(assigns) do
    ~H"""
    <span class={[
      "text-[9px] font-mono font-bold uppercase tracking-widest px-2 py-1 rounded-sm border",
      @status in ~w(active approved) && "text-emerald-400 border-emerald-400/30 bg-emerald-400/10",
      @status == "pending" && "text-amber-400 border-amber-400/30 bg-amber-400/10",
      @status in ~w(registered under_review) && "text-sky-400 border-sky-400/30 bg-sky-400/10",
      @status == "rejected" && "text-red-400 border-red-400/30 bg-red-400/10",
      @status not in ~w(active approved pending registered under_review rejected) &&
        "text-zinc-500 border-zinc-700 bg-zinc-900",
      @class
    ]}>
      {@status}
    </span>
    """
  end

  # ── status_pill ───────────────────────────────────────────────────────────────

  attr :status, :string, required: true
  attr :class, :string, default: nil

  def status_pill(assigns) do
    ~H"""
    <span class={[
      "status-pill border",
      @status == "approved" && "bg-emerald-400/10 text-emerald-400 border-emerald-400/20",
      @status == "pending" && "bg-amber-400/10 text-amber-400 border-amber-400/20",
      @status == "rejected" && "bg-rose-400/10 text-rose-400 border-rose-400/20",
      @status == "under_review" && "bg-sky-400/10 text-sky-400 border-sky-400/20",
      @status == "archived" && "bg-zinc-800/60 text-zinc-500 border-zinc-700/50",
      @status not in ~w(approved pending rejected under_review archived) &&
        "bg-zinc-800/60 text-zinc-500 border-zinc-700/50",
      @class
    ]}>
      <div class="w-1.5 h-1.5 rounded-full bg-current"></div>
      {String.upcase(@status)}
    </span>
    """
  end

  # ── ledger_table ──────────────────────────────────────────────────────────────
  # A high-density, institutional-grade data table.

  attr :id, :string, required: true
  attr :rows, :list, required: true
  attr :row_id, :any, default: nil

  slot :col, required: true do
    attr :label, :string
    attr :class, :string
  end

  slot :action

  def ledger_table(assigns) do
    ~H"""
    <div class="ledger-table-container flex-1 overflow-auto custom-scrollbar">
      <table class="w-full text-left border-collapse ledger-table">
        <thead>
          <tr class="border-b border-white/10 bg-white/[0.02]">
            <th :for={col <- @col} class="px-6 py-5 tech-label text-zinc-400">
              {col[:label]}
            </th>
            <th :if={@action != []} class="px-6 py-5 tech-label text-zinc-400 text-right">Action</th>
          </tr>
        </thead>
        <tbody id={@id} class="divide-y divide-white/5">
          <tr
            :for={row <- @rows}
            class="ledger-row group relative hover:bg-white/[0.02] transition-colors duration-300"
          >
            <td
              :for={col <- @col}
              class={[
                "px-6 py-5 font-mono text-xs text-white/80 transition-colors group-hover:text-white",
                col[:class]
              ]}
            >
              {render_slot(col, row)}
            </td>
            <td :if={@action != []} class="px-6 py-5 text-right">
              <div class="flex justify-end gap-3 opacity-0 group-hover:opacity-100 transition-all duration-300">
                {render_slot(@action, row)}
              </div>
            </td>
          </tr>
        </tbody>
      </table>
    </div>
    """
  end

  # ── ledger_pagination ─────────────────────────────────────────────────────────
  # The institutional pagination bar matching RequestAccessAdminLive.

  attr :page, :integer, required: true
  attr :per_page, :integer, required: true
  attr :total_count, :integer, required: true
  attr :total_pages, :integer, required: true
  attr :extra_label, :string, default: nil
  attr :extra_count, :integer, default: nil
  attr :approved_count, :integer, default: nil

  def ledger_pagination(assigns) do
    extra_label = assigns[:extra_label] || if(assigns[:approved_count], do: "Approved", else: nil)
    extra_count = assigns[:extra_count] || assigns[:approved_count]
    assigns = assign(assigns, extra_label: extra_label, extra_count: extra_count)

    ~H"""
    <div class="flex-shrink-0 px-8 py-5 border-t border-white/10 bg-black/30 flex flex-wrap items-center justify-between gap-4">
      <div class="flex items-center gap-5">
        <span class="text-[9px] font-mono text-zinc-500 uppercase tracking-wider">
          Range:
          <span class="text-white">
            {if @total_count == 0, do: 0, else: (@page - 1) * @per_page + 1} - {min(
              @page * @per_page,
              @total_count
            )}
          </span>
        </span>
        <div class="h-3 w-px bg-white/10"></div>
        <span class="text-[9px] font-mono text-zinc-500 uppercase tracking-wider">
          Total: <span class="text-white">{@total_count}</span>
        </span>
        <div :if={@extra_label && @extra_count} class="h-3 w-px bg-white/10 hidden sm:block"></div>
        <span
          :if={@extra_label && @extra_count}
          class="text-[9px] font-mono text-zinc-500 uppercase tracking-wider hidden sm:inline"
        >
          {@extra_label}: <span class="text-emerald-400">{@extra_count}</span>
        </span>
      </div>
      <div class="flex items-center gap-3">
        <form phx-change="change_page_size">
          <select
            name="page_size"
            class="bg-black/40 border border-white/10 rounded-lg px-3 py-2 text-[9px] font-mono text-white focus:outline-none focus:border-emerald-400/40 cursor-pointer"
          >
            <%= for size <- [10, 25, 50, 100] do %>
              <option value={size} selected={@per_page == size}>{size} / page</option>
            <% end %>
          </select>
        </form>

        <button
          phx-click="paginate"
          phx-value-page={@page - 1}
          disabled={@page <= 1}
          class="flex items-center gap-2 px-5 py-2 rounded-full border border-white/10 text-[9px] font-black uppercase tracking-wider text-zinc-400 hover:text-white hover:border-emerald-400/50 transition-all disabled:opacity-30 cursor-pointer disabled:cursor-not-allowed"
        >
          <.icon name="hero-chevron-left-mini" class="w-3 h-3" /> Prev
        </button>

        <span class="text-[9px] font-mono text-zinc-500">
          Page {@page} of {max(1, @total_pages)}
        </span>

        <button
          phx-click="paginate"
          phx-value-page={@page + 1}
          disabled={@page >= @total_pages}
          class="flex items-center gap-2 px-5 py-2 rounded-full border border-white/10 text-[9px] font-black uppercase tracking-wider text-zinc-400 hover:text-white hover:border-emerald-400/50 transition-all disabled:opacity-30 cursor-pointer disabled:cursor-not-allowed"
        >
          Next <.icon name="hero-chevron-right-mini" class="w-3 h-3" />
        </button>
      </div>
    </div>
    """
  end

  # ── ledger_empty_state ────────────────────────────────────────────────────────
  # Premium empty state container for ledger tables.

  attr :icon, :string, default: "hero-clipboard-document-check"
  attr :title, :string, default: "No records found"
  attr :subtitle, :string, default: "Try adjusting your search or filter parameters"
  attr :action_label, :string, default: nil
  attr :action_event, :string, default: nil

  def ledger_empty_state(assigns) do
    ~H"""
    <div class="flex flex-col items-center justify-center py-24 px-4 text-center">
      <.icon name={@icon} class="size-12 text-zinc-800 mb-4 opacity-50" />
      <p class="text-zinc-400 font-mono text-sm tracking-tight font-bold">
        {@title}
      </p>
      <p class="text-zinc-600 text-[11px] font-mono uppercase tracking-widest mt-2 max-w-sm">
        {@subtitle}
      </p>
      <button
        :if={@action_label && @action_event}
        phx-click={@action_event}
        class="mt-8 px-6 py-2.5 border border-emerald-400/30 text-emerald-400 text-[10px] font-mono uppercase tracking-[0.2em] hover:bg-emerald-400/10 transition-all rounded-sm cursor-pointer"
      >
        {@action_label}
      </button>
    </div>
    """
  end

  # ── hud_metric_card ───────────────────────────────────────────────────────────
  # Professional fintech HUD metric container with crisp rounded-2xl geometry.

  attr :label, :string, required: true
  attr :value, :any, required: true
  attr :status, :string, default: nil
  attr :color, :string, values: ~w(emerald amber rose sky zinc purple), default: "emerald"
  attr :class, :string, default: nil

  def hud_metric_card(assigns) do
    ~H"""
    <div class={[
      "rounded-2xl bg-[#050509]/80 backdrop-blur-xl border border-white/10 p-6 relative group overflow-hidden shadow-2xl transition-all duration-500 hover:border-white/20",
      @class
    ]}>
      <div class={[
        "absolute top-0 left-0 w-1 h-full opacity-30 group-hover:opacity-100 transition-opacity duration-500",
        @color == "emerald" && "bg-emerald-400",
        @color == "amber" && "bg-amber-400",
        @color == "rose" && "bg-rose-400",
        @color == "sky" && "bg-sky-400",
        @color == "zinc" && "bg-zinc-400",
        @color == "purple" && "bg-purple-400"
      ]}>
      </div>
      <div class="flex justify-between items-center mb-4">
        <p class="text-[10px] font-mono font-bold text-zinc-500 uppercase tracking-[0.25em] pl-1">
          {@label}
        </p>
        <div class={[
          "w-2 h-2 rounded-full animate-pulse",
          @color == "emerald" && "bg-emerald-400 shadow-[0_0_10px_#34d399]",
          @color == "amber" && "bg-amber-400 shadow-[0_0_10px_#fbbf24]",
          @color == "rose" && "bg-rose-400 shadow-[0_0_10px_#f43f5e]",
          @color == "sky" && "bg-sky-400 shadow-[0_0_10px_#38bdf8]",
          @color == "zinc" && "bg-zinc-400 shadow-[0_0_10px_#a1a1aa]",
          @color == "purple" && "bg-purple-400 shadow-[0_0_10px_#c084fc]"
        ]}>
        </div>
      </div>
      <div class="flex items-baseline justify-between pl-1">
        <p class="text-3xl font-black text-white tracking-tight tabular-nums font-mono">
          {@value}
        </p>
        <span
          :if={@status}
          class={[
            "text-[8px] font-mono font-black uppercase tracking-widest px-2 py-0.5 rounded border ml-2 text-right",
            @color == "emerald" && "text-emerald-400 border-emerald-400/20 bg-emerald-400/5",
            @color == "amber" && "text-amber-400 border-amber-400/20 bg-amber-400/5",
            @color == "rose" && "text-rose-400 border-rose-400/20 bg-rose-400/5",
            @color == "sky" && "text-sky-400 border-sky-400/20 bg-sky-400/5",
            @color == "zinc" && "text-zinc-400 border-zinc-400/20 bg-zinc-400/5",
            @color == "purple" && "text-purple-400 border-purple-400/20 bg-purple-400/5"
          ]}
        >
          {@status}
        </span>
      </div>
    </div>
    """
  end

  # ── screening_pill ────────────────────────────────────────────────────────────
  # Only renders for "pending" or "flagged" — "clean" and nil are invisible.

  attr :screening, :string, default: nil
  attr :class, :string, default: nil

  def screening_pill(assigns) do
    ~H"""
    <span
      :if={@screening in ["pending", "flagged"]}
      class={[
        "status-pill border",
        @screening == "pending" && "bg-amber-400/10 text-amber-400 border-amber-400/20",
        @screening == "flagged" && "bg-rose-500/10 text-rose-400 border-rose-500/20",
        @class
      ]}
    >
      <div class="w-1.5 h-1.5 rounded-full bg-current"></div>
      {if @screening == "pending", do: "SCREENING", else: "FLAGGED"}
    </span>
    """
  end

  # ── eq_drawer_field ───────────────────────────────────────────────────────────

  attr :label, :string, required: true
  attr :value, :string, required: true

  def eq_drawer_field(assigns) do
    ~H"""
    <div class="space-y-1">
      <span class="text-[10px] font-medium text-zinc-500 uppercase tracking-wider">
        {@label}
      </span>
      <p class="text-sm text-zinc-200 font-medium">{@value}</p>
    </div>
    """
  end

  # ── eq_control_bar ────────────────────────────────────────────────────────────
  # The horizontal container for control clusters (search, filters, view modes).

  slot :inner_block, required: true

  def eq_control_bar(assigns) do
    ~H"""
    <div class="flex-shrink-0 mb-6 flex items-center justify-between gap-4 relative z-[100]">
      {render_slot(@inner_block)}
    </div>
    """
  end

  # ── eq_control_cluster ─────────────────────────────────────────────────────────
  # A grouping container for controls like search inputs or filter buttons.

  slot :inner_block, required: true

  def eq_control_cluster(assigns) do
    ~H"""
    <div class="control-cluster">
      {render_slot(@inner_block)}
    </div>
    """
  end

  # ── eq_batch_actions ──────────────────────────────────────────────────────────
  # The floating action bar for bulk operations.

  attr :show, :boolean, default: false
  attr :count, :integer, default: 0
  slot :inner_block, required: true

  def eq_batch_actions(assigns) do
    ~H"""
    <div
      id="batch-actions"
      class={[
        "batch-actions-elite fixed bottom-8 left-1/2 -translate-x-1/2 z-[35] bg-[#0a0a0f]/90 backdrop-blur-xl border border-white/10 rounded-2xl px-6 py-4 flex items-center gap-6 shadow-2xl",
        @show && "visible"
      ]}
    >
      <div class="flex items-center gap-3 pr-6 border-r border-white/10">
        <.icon name="hero-layers-mini" class="w-4 h-4 text-emerald-400" />
        <span class="text-xs font-mono font-bold text-white">
          {@count} selected
        </span>
      </div>
      {render_slot(@inner_block)}
    </div>
    """
  end

  # ── Private ───────────────────────────────────────────────────────────────────

  slot :inner_block, required: true

  defp eq_field_error(assigns) do
    ~H"""
    <p class="mt-2 flex items-center gap-1.5 font-mono text-[9px] text-red-400 uppercase tracking-wider">
      <.icon name="hero-exclamation-triangle-mini" class="size-3 flex-shrink-0" />
      {render_slot(@inner_block)}
    </p>
    """
  end
end
