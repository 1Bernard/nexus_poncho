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
          "bg-emerald-400 text-black hover:bg-white shadow-lg shadow-emerald-400/10"

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
        "px-8 py-3.5 rounded-xl",
        "text-[10px] font-bold uppercase tracking-widest",
        "transition-all duration-200 disabled:opacity-40 disabled:cursor-not-allowed",
        variant_class,
        assigns.full_width && "w-full",
        assigns.class
      ])

    ~H"""
    <%= if @rest[:navigate] || @rest[:patch] || @rest[:href] do %>
      <.link class={@computed_class} {@rest}>
        {render_slot(@inner_block)}
      </.link>
    <% else %>
      <button class={@computed_class} {@rest}>
        {render_slot(@inner_block)}
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
  attr :row_numbers, :boolean, default: false
  attr :grid_guides, :boolean, default: false

  slot :col, required: true do
    attr :label, :string
    attr :class, :string
  end

  slot :checkbox_header
  slot :checkbox

  slot :action

  def ledger_table(assigns) do
    ~H"""
    <div class="ledger-table-container flex-1 overflow-auto custom-scrollbar">
      <table class="w-full text-left border-collapse ledger-table">
        <thead>
          <tr class="border-b border-white/10 bg-white/[0.02]">
            <th :if={@checkbox != []} class="pl-8 pr-4 py-5 w-12">
              {render_slot(@checkbox_header)}
            </th>
            <th :if={@row_numbers} class="px-6 py-5 tech-label text-zinc-400 w-12">#</th>
            <th :for={col <- @col} class="px-6 py-5 tech-label text-zinc-400">
              {col[:label]}
            </th>
            <th :if={@action != []} class="px-6 py-5 tech-label text-zinc-400 text-right">Action</th>
          </tr>
        </thead>
        <tbody
          id={@id}
          phx-update={is_struct(@rows, Phoenix.LiveView.LiveStream) && "stream"}
          class="divide-y divide-white/5 ledger-tbody"
        >
          <tr
            :for={row <- @rows}
            id={get_ledger_row_id(row, @row_id)}
            class="ledger-row group relative hover:bg-white/[0.02] transition-colors duration-300"
          >
            <%!-- Elite Grid Guides --%>
            <div
              :if={@grid_guides}
              class={["grid-guide-v", if(@checkbox != [], do: "left-8", else: "left-6")]}
            >
            </div>
            <div :if={@grid_guides && @checkbox != []} class="grid-guide-v left-[calc(8rem+48px)]">
            </div>
            <div :if={@grid_guides} class="grid-guide-h top-0"></div>
            <div :if={@grid_guides} class="grid-guide-h bottom-0"></div>

            <td :if={@checkbox != []} class="pl-8 pr-4 py-5">
              {render_slot(@checkbox, get_ledger_row_item(row))}
            </td>
            <td :if={@row_numbers} class="px-6 py-5">
              <span class="row-num text-xs text-zinc-500"></span>
            </td>
            <td
              :for={col <- @col}
              class={[
                "px-6 py-5 font-mono text-xs text-white/80 transition-colors group-hover:text-white",
                col[:class]
              ]}
            >
              {render_slot(col, get_ledger_row_item(row))}
            </td>
            <td :if={@action != []} class="px-6 py-5 text-right">
              <div class="flex justify-end gap-3 opacity-0 group-hover:opacity-100 transition-all duration-300">
                {render_slot(@action, get_ledger_row_item(row))}
              </div>
            </td>
          </tr>
        </tbody>
      </table>
    </div>
    """
  end

  defp get_ledger_row_id({dom_id, _item}, _row_id_fun), do: dom_id
  defp get_ledger_row_id(_item, nil), do: nil
  defp get_ledger_row_id(item, row_id_fun) when is_function(row_id_fun), do: row_id_fun.(item)

  defp get_ledger_row_item({dom_id, item}) when is_binary(dom_id), do: item
  defp get_ledger_row_item(item), do: item

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
      "rounded-2xl bg-[#08080d] border border-white/[0.06] p-6 relative group overflow-hidden",
      "shadow-[0_8px_32px_rgba(0,0,0,0.5)] transition-all duration-500",
      "hover:border-white/[0.12] hover:shadow-[0_12px_48px_rgba(0,0,0,0.6)]",
      @class
    ]}>
      <%!-- Subtle top shimmer line — replaces the chunky left border ---%>
      <div class={[
        "absolute top-0 left-6 right-6 h-px opacity-0 group-hover:opacity-100 transition-opacity duration-500",
        @color == "emerald" && "bg-gradient-to-r from-transparent via-emerald-400/60 to-transparent",
        @color == "amber" && "bg-gradient-to-r from-transparent via-amber-400/60 to-transparent",
        @color == "rose" && "bg-gradient-to-r from-transparent via-rose-400/60 to-transparent",
        @color == "sky" && "bg-gradient-to-r from-transparent via-sky-400/60 to-transparent",
        @color == "zinc" && "bg-gradient-to-r from-transparent via-zinc-400/60 to-transparent",
        @color == "purple" && "bg-gradient-to-r from-transparent via-purple-400/60 to-transparent"
      ]}>
      </div>

      <%!-- Label row with live indicator ---%>
      <div class="flex justify-between items-center mb-5">
        <p class="text-[9px] font-mono font-bold text-zinc-600 uppercase tracking-[0.3em]">
          {@label}
        </p>
        <div class={[
          "w-1.5 h-1.5 rounded-full animate-pulse",
          @color == "emerald" && "bg-emerald-400/70 shadow-[0_0_6px_#34d399]",
          @color == "amber" && "bg-amber-400/70 shadow-[0_0_6px_#fbbf24]",
          @color == "rose" && "bg-rose-400/70 shadow-[0_0_6px_#f43f5e]",
          @color == "sky" && "bg-sky-400/70 shadow-[0_0_6px_#38bdf8]",
          @color == "zinc" && "bg-zinc-500/70 shadow-[0_0_6px_#a1a1aa]",
          @color == "purple" && "bg-purple-400/70 shadow-[0_0_6px_#c084fc]"
        ]}>
        </div>
      </div>

      <%!-- Value ---%>
      <p class="text-[2rem] font-black text-white tracking-tight tabular-nums leading-none mb-3">
        {@value}
      </p>

      <%!-- Status tag — bottom separator row ---%>
      <div class="flex items-center justify-between pt-4 border-t border-white/[0.04]">
        <span
          :if={@status}
          class={[
            "text-[8px] font-mono font-black uppercase tracking-widest",
            @color == "emerald" && "text-emerald-400/60",
            @color == "amber" && "text-amber-400/60",
            @color == "rose" && "text-rose-400/60",
            @color == "sky" && "text-sky-400/60",
            @color == "zinc" && "text-zinc-500/60",
            @color == "purple" && "text-purple-400/60"
          ]}
        >
          {@status}
        </span>
        <div class={[
          "h-0.5 flex-1 ml-3 rounded-full opacity-0 group-hover:opacity-100 transition-opacity duration-700",
          @color == "emerald" && "bg-gradient-to-r from-emerald-400/20 to-transparent",
          @color == "amber" && "bg-gradient-to-r from-amber-400/20 to-transparent",
          @color == "rose" && "bg-gradient-to-r from-rose-400/20 to-transparent",
          @color == "sky" && "bg-gradient-to-r from-sky-400/20 to-transparent",
          @color == "zinc" && "bg-gradient-to-r from-zinc-400/20 to-transparent",
          @color == "purple" && "bg-gradient-to-r from-purple-400/20 to-transparent"
        ]}>
        </div>
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

  # ── eq_table_toolbar ──────────────────────────────────────────────────────────
  # Standard above-table toolbar: search pill + optional Refine dropdown + count
  # + optional right-side actions slot.
  #
  # Usage:
  #   <.eq_table_toolbar
  #     search_value={@search}
  #     search_event="search"
  #     search_placeholder="Search members..."
  #     count={@total_count}
  #     count_label="member"
  #     show_refine={true}
  #     filter_active={@filter != "all"}
  #   >
  #     <:filter_panel>  ... filter pill buttons ...  </:filter_panel>
  #     <:actions>       ... Export button etc ...    </:actions>
  #   </.eq_table_toolbar>

  attr :search_value, :string, default: ""
  attr :search_event, :string, default: "search"
  attr :search_name, :string, default: "search"
  attr :search_placeholder, :string, default: "Search..."
  attr :count, :integer, default: nil
  attr :count_label, :string, default: "record"
  attr :show_refine, :boolean, default: false
  attr :filter_active, :boolean, default: false
  attr :show_filters, :boolean, default: false
  attr :kbd_hint, :boolean, default: true
  attr :class, :string, default: nil

  slot :filter_panel
  slot :actions

  def eq_table_toolbar(assigns) do
    ~H"""
    <div class={["flex items-center justify-between gap-4 relative z-[100]", @class]}>
      <%!-- Left: search + optional Refine --%>
      <div class="control-cluster">
        <%!-- Search --%>
        <div class="relative flex items-center pl-3">
          <.icon name="hero-magnifying-glass-mini" class="w-3.5 h-3.5 text-zinc-500 flex-shrink-0" />
          <form phx-change={@search_event} class="flex items-center m-0 p-0">
            <input
              type="text"
              name={@search_name}
              id={"toolbar-search-#{@search_name}"}
              value={@search_value}
              phx-debounce="300"
              phx-hook="AdminSearch"
              placeholder={@search_placeholder}
              class="search-input py-2 px-3 text-xs text-white placeholder:text-zinc-600 focus:outline-none"
            />
          </form>
          <div class="absolute right-3 flex items-center pointer-events-none">
            <span :if={@kbd_hint} class="kbd-hint font-mono hidden md:block text-zinc-600">⌘K</span>
          </div>
        </div>

        <%!-- Refine button + dropdown --%>
        <div :if={@show_refine && @filter_panel != []} class="flex items-center">
          <div class="cluster-divider"></div>
          <div class="relative">
            <button
              phx-click="toggle_filters"
              class={[
                "flex items-center gap-2 px-4 py-2 rounded-lg text-[10px] font-bold transition-all uppercase tracking-widest",
                @filter_active && "text-emerald-400 hover:bg-emerald-400/5",
                !@filter_active && "text-zinc-400 hover:text-white hover:bg-white/5"
              ]}
            >
              <.icon name="hero-adjustments-horizontal-mini" class="w-3.5 h-3.5" /> Refine
              <span
                :if={@filter_active}
                class="w-1.5 h-1.5 rounded-full bg-emerald-400 shadow-[0_0_6px_#34d399]"
              >
              </span>
            </button>
            <div
              id="filter-dropdown"
              phx-click-away="close_filters"
              class={[
                "absolute left-0 top-[calc(100%+12px)] w-72 rounded-2xl p-5",
                @show_filters && "open"
              ]}
            >
              {render_slot(@filter_panel)}
            </div>
          </div>
        </div>
      </div>

      <%!-- Right: actions slot --%>
      <div class="flex items-center gap-4">
        <div :if={@actions != []} class="control-cluster">
          {render_slot(@actions)}
        </div>
      </div>
    </div>
    """
  end

  # ── eq_table_footer ───────────────────────────────────────────────────────────
  # The institutional table footer matching the prestige style.
  # Includes system count, audit protocol status, and return navigation link.

  attr :count_value, :any, required: true
  attr :count_label, :string, default: "System Roster Count"
  attr :count_sublabel, :string, default: "ENTITIES"
  attr :protocol_label, :string, default: "Audit Protocol"
  attr :protocol_value, :string, default: "NON-REPUDIATION ACTIVE"
  attr :protocol_color, :string, default: "emerald"
  attr :return_label, :string, default: "Return to System Hub"
  attr :return_path, :string, required: true

  def eq_table_footer(assigns) do
    ~H"""
    <div class="mt-8 pt-8 border-t border-white/[0.02] flex flex-col sm:flex-row justify-between items-start sm:items-center gap-6 relative">
      <%!-- Subtle tech corners --%>
      <div class="absolute left-0 top-0 w-2 h-px bg-emerald-400/20"></div>
      <div class="absolute left-0 top-0 w-px h-2 bg-emerald-400/20"></div>

      <div class="flex flex-wrap items-center gap-6 md:gap-8">
        <div class="flex items-center gap-3">
          <div class="w-1.5 h-1.5 rounded-full bg-zinc-600 animate-pulse"></div>
          <div class="flex flex-col">
            <span class="text-[8px] font-mono font-black text-zinc-500 uppercase tracking-[0.2em] mb-0.5">
              {@count_label}
            </span>
            <span class="text-[11px] font-mono font-bold text-zinc-400">
              {@count_value} {@count_sublabel}
            </span>
          </div>
        </div>

        <div class="hidden sm:block w-px h-8 bg-white/5"></div>

        <div class="flex items-center gap-3">
          <div class={[
            "w-1.5 h-1.5 rounded-full",
            @protocol_color == "emerald" && "bg-emerald-400 animate-pulse shadow-[0_0_6px_#34d399]",
            @protocol_color == "amber" && "bg-amber-400 animate-pulse shadow-[0_0_6px_#fbbf24]",
            @protocol_color == "rose" && "bg-rose-400 animate-pulse shadow-[0_0_6px_#f43f5e]",
            @protocol_color == "sky" && "bg-sky-400 animate-pulse shadow-[0_0_6px_#38bdf8]"
          ]}>
          </div>
          <div class="flex flex-col">
            <span class="text-[8px] font-mono font-black text-zinc-500 uppercase tracking-[0.2em] mb-0.5">
              {@protocol_label}
            </span>
            <span class={[
              "text-[10px] font-mono font-black uppercase tracking-widest",
              @protocol_color == "emerald" && "text-emerald-400/80",
              @protocol_color == "amber" && "text-amber-400/80",
              @protocol_color == "rose" && "text-rose-400/80",
              @protocol_color == "sky" && "text-sky-400/80"
            ]}>
              {@protocol_value}
            </span>
          </div>
        </div>
      </div>

      <.link
        navigate={@return_path}
        class="text-[9px] font-mono font-black text-zinc-500 hover:text-white transition-all duration-300 uppercase tracking-[0.2em] flex items-center gap-2 group border border-white/5 hover:border-white/10 rounded-lg px-4 py-2 bg-white/[0.01] hover:bg-white/[0.04]"
      >
        <.icon
          name="hero-arrow-left-mini"
          class="w-3.5 h-3.5 group-hover:-translate-x-1 transition-transform"
        />
        {@return_label}
      </.link>
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
