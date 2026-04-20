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

  attr :variant, :string, values: ~w(primary ghost danger), default: "primary"
  attr :full_width, :boolean, default: false
  attr :class, :string, default: nil
  attr :rest, :global

  slot :inner_block, required: true

  def eq_button(assigns) do
    variant_class =
      case assigns.variant do
        "primary" ->
          "bg-emerald-400 text-black hover:bg-emerald-300 shadow-[0_0_20px_rgba(52,211,153,0.15)]"

        "ghost" ->
          "border border-emerald-400/30 text-emerald-400 hover:bg-emerald-400/10"

        "danger" ->
          "border border-red-500/30 text-red-400 hover:bg-red-500/10"
      end

    assigns =
      assign(assigns, :computed_class, [
        "inline-flex items-center justify-center gap-2",
        "px-6 py-4 rounded-xl",
        "text-[10px] font-black uppercase tracking-[0.25em]",
        "transition-all duration-300 disabled:opacity-40 disabled:cursor-not-allowed",
        variant_class,
        assigns.full_width && "w-full",
        assigns.class
      ])

    ~H"""
    <button class={@computed_class} {@rest}>
      {render_slot(@inner_block)}
    </button>
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
      @status == "active" && "text-emerald-400 border-emerald-400/30 bg-emerald-400/10",
      @status == "pending" && "text-amber-400 border-amber-400/30 bg-amber-400/10",
      @status == "registered" && "text-sky-400 border-sky-400/30 bg-sky-400/10",
      @status not in ~w(active pending registered) &&
        "text-zinc-500 border-zinc-700 bg-zinc-900",
      @class
    ]}>
      {@status}
    </span>
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
