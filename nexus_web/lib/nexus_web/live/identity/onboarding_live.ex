defmodule NexusWeb.Identity.OnboardingLive do
  use NexusWeb, :live_view

  alias Nexus.Identity.Commands.EnrollBiometric
  alias Nexus.Identity.Queries.GetUser
  alias Nexus.Identity.WebAuthn
  alias Nexus.Identity.WebAuthn.BiometricInvitation

  alias Nexus.Onboarding.Commands.{
    AcceptTerms,
    DeclareUBOs,
    SubmitEntityProfile,
    UploadKYBDocument
  }

  alias Nexus.Onboarding.Storage.DocumentStore
  require Logger

  @entity_admin_roles ~w(org_admin group_treasurer)
  @max_projection_retries 50
  @projection_retry_ms 200
  @terms_version "v2026-01"
  @required_doc_types ~w(certificate_of_incorporation proof_of_address)

  @impl true
  def mount(%{"token" => token}, _session, socket) do
    Logger.info("[OnboardingUI] Verifying invitation token")

    case BiometricInvitation.verify_token(token) do
      {:ok, user_id} ->
        user = GetUser.execute(user_id)
        steps = build_steps(user)

        socket =
          socket
          |> assign(:user_id, user_id)
          |> assign(:user, user)
          |> assign(:token, token)
          |> assign(:steps, steps)
          |> assign(:step, List.first(steps))
          |> assign(:status, if(user, do: :idle, else: :loading))
          |> assign(:current_origin, nil)
          |> assign(:error, nil)
          |> assign(:retry_count, 0)
          |> assign(:entity_form, %{
            "legal_name" => "",
            "country" => "",
            "registration_number" => "",
            "registered_address" => "",
            "tax_id" => "",
            "industry" => ""
          })
          |> assign(:entity_errors, %{})
          |> assign(:ubos, [blank_ubo()])
          |> assign(:uploaded_docs, %{})
          |> assign(:upload_errors, %{})
          |> assign(:terms_accepted, false)
          |> assign(:accepted_by_title, "")

        socket =
          if connected?(socket) do
            socket
            |> allow_upload(:cert_of_inc,
              accept: ~w(.pdf .jpg .jpeg .png),
              max_entries: 1,
              max_file_size: 20_000_000
            )
            |> allow_upload(:proof_addr,
              accept: ~w(.pdf .jpg .jpeg .png),
              max_entries: 1,
              max_file_size: 20_000_000
            )
            |> allow_upload(:memo_of_assoc,
              accept: ~w(.pdf .jpg .jpeg .png),
              max_entries: 1,
              max_file_size: 20_000_000
            )
            |> allow_upload(:shareholder_reg,
              accept: ~w(.pdf .jpg .jpeg .png),
              max_entries: 1,
              max_file_size: 20_000_000
            )
          else
            socket
          end

        if connected?(socket) && is_nil(user) do
          Process.send_after(self(), :await_projection, @projection_retry_ms)
        end

        {:ok, socket}

      {:error, reason} ->
        Logger.warning("[OnboardingUI] Token verification failed: #{inspect(reason)}")
        {:ok, redirect(socket, to: "/")}
    end
  end

  def mount(_params, _session, socket), do: {:ok, redirect(socket, to: "/")}

  @impl true
  def handle_params(_params, uri, socket) do
    uri_struct = URI.parse(uri)

    origin =
      "#{uri_struct.scheme}://#{uri_struct.host}#{if uri_struct.port, do: ":#{uri_struct.port}"}"

    {:noreply, assign(socket, current_origin: origin)}
  end

  @impl true
  def handle_info(:await_projection, %{assigns: %{user_id: user_id, retry_count: count}} = socket) do
    case GetUser.execute(user_id) do
      nil when count < @max_projection_retries ->
        Process.send_after(self(), :await_projection, @projection_retry_ms)
        {:noreply, assign(socket, retry_count: count + 1)}

      nil ->
        Logger.warning("[OnboardingUI] Projection timeout after #{count} retries for #{user_id}")

        {:noreply,
         socket
         |> put_flash(:error, "Identity record not ready. Please refresh in a moment.")
         |> push_navigate(to: "/register")}

      user ->
        steps = build_steps(user)

        {:noreply,
         socket
         |> assign(:user, user)
         |> assign(:status, :idle)
         |> assign(:steps, steps)
         |> assign(:step, List.first(steps))}
    end
  end

  def handle_info(:refresh_after_step, socket) do
    {:noreply, socket}
  end

  # ── Step Navigation ───────────────────────────────────────────────────────

  @impl true
  def handle_event("next_step", _params, socket) do
    {:noreply, advance_step(socket)}
  end

  @impl true
  def handle_event("prev_step", _params, socket) do
    {:noreply, go_back(socket)}
  end

  # ── Entity Details ────────────────────────────────────────────────────────

  @impl true
  def handle_event("update_entity", %{"entity" => params}, socket) do
    {:noreply, assign(socket, entity_form: Map.merge(socket.assigns.entity_form, params))}
  end

  @impl true
  def handle_event("submit_entity_profile", %{"entity" => params}, socket) do
    form = Map.merge(socket.assigns.entity_form, params)
    errors = validate_entity_form(form)

    if map_size(errors) == 0 do
      user = socket.assigns.user

      command = %SubmitEntityProfile{
        org_id: user.org_id,
        submitted_by: user.id,
        legal_name: form["legal_name"],
        country: form["country"],
        registration_number: form["registration_number"],
        registered_address: form["registered_address"],
        tax_id: Map.get(form, "tax_id"),
        industry: form["industry"]
      }

      case Nexus.App.dispatch(command,
             metadata: %{"idempotency_key" => "entity_profile:#{user.org_id}"}
           ) do
        :ok ->
          {:noreply,
           socket |> assign(:entity_form, form) |> assign(:entity_errors, %{}) |> advance_step()}

        {:error, :entity_profile_already_submitted} ->
          {:noreply, advance_step(socket)}

        {:error, reason} ->
          Logger.error("[OnboardingUI] SubmitEntityProfile failed: #{inspect(reason)}")
          {:noreply, assign(socket, :error, "Failed to save entity profile. Please try again.")}
      end
    else
      {:noreply, assign(socket, entity_form: form, entity_errors: errors)}
    end
  end

  # ── UBOs ──────────────────────────────────────────────────────────────────

  @impl true
  def handle_event("update_ubos_form", params, socket) do
    ubos =
      case Map.get(params, "ubos") do
        nil ->
          socket.assigns.ubos

        ubo_map ->
          ubo_map
          |> Enum.sort_by(fn {k, _} -> String.to_integer(k) end)
          |> Enum.map(fn {_, ubo} -> ubo end)
      end

    {:noreply, assign(socket, :ubos, ubos)}
  end

  @impl true
  def handle_event("add_ubo", _params, socket) do
    {:noreply, assign(socket, :ubos, socket.assigns.ubos ++ [blank_ubo()])}
  end

  @impl true
  def handle_event("remove_ubo", %{"index" => index_str}, socket) do
    index = String.to_integer(index_str)
    ubos = List.delete_at(socket.assigns.ubos, index)
    ubos = if ubos == [], do: [blank_ubo()], else: ubos
    {:noreply, assign(socket, :ubos, ubos)}
  end

  @impl true
  def handle_event("submit_ubos", params, socket) do
    ubos =
      case Map.get(params, "ubos") do
        nil ->
          socket.assigns.ubos

        ubo_map ->
          ubo_map
          |> Enum.sort_by(fn {k, _} -> String.to_integer(k) end)
          |> Enum.map(fn {_, ubo} -> ubo end)
      end

    valid_ubos = Enum.filter(ubos, fn ubo -> ubo["name"] != "" end)
    user = socket.assigns.user

    command = %DeclareUBOs{
      org_id: user.org_id,
      declared_by: user.id,
      beneficial_owners: valid_ubos
    }

    case Nexus.App.dispatch(command,
           metadata: %{"idempotency_key" => "ubos:#{user.org_id}"}
         ) do
      :ok ->
        {:noreply, socket |> assign(:ubos, ubos) |> advance_step()}

      {:error, reason} ->
        Logger.error("[OnboardingUI] DeclareUBOs failed: #{inspect(reason)}")
        {:noreply, assign(socket, :error, "Failed to declare UBOs. Please try again.")}
    end
  end

  # ── Document Uploads ──────────────────────────────────────────────────────

  @impl true
  def handle_event("validate_doc", _params, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_event("upload_doc", %{"doc_type" => doc_type}, socket) do
    upload_key = doc_type_to_upload_key(doc_type)
    user = socket.assigns.user

    results =
      consume_uploaded_entries(socket, upload_key, fn %{path: path}, entry ->
        content = File.read!(path)
        content_type = entry.client_type || "application/octet-stream"

        case DocumentStore.upload(user.org_id, doc_type, entry.client_name, content, content_type) do
          {:ok, file_key} ->
            {:ok, {file_key, entry.client_name, entry.client_size, content_type}}

          {:error, reason} ->
            {:postpone, reason}
        end
      end)

    case results do
      [{:ok, {file_key, file_name, file_size, content_type}}] ->
        command = %UploadKYBDocument{
          document_id: Uniq.UUID.uuid7(),
          org_id: user.org_id,
          uploaded_by: user.id,
          document_type: doc_type,
          file_key: file_key,
          file_name: file_name,
          file_size: file_size,
          content_type: content_type,
          storage_bucket: System.get_env("S3_BUCKET") || "nexus-kyb-documents"
        }

        case Nexus.App.dispatch(command,
               metadata: %{"idempotency_key" => "doc:#{user.org_id}:#{doc_type}"}
             ) do
          :ok ->
            doc_record = %{file_name: file_name, file_key: file_key}
            uploaded = Map.put(socket.assigns.uploaded_docs, doc_type, doc_record)
            errors = Map.delete(socket.assigns.upload_errors, doc_type)

            {:noreply,
             socket |> assign(:uploaded_docs, uploaded) |> assign(:upload_errors, errors)}

          {:error, reason} ->
            err = "Command failed: #{inspect(reason)}"

            {:noreply,
             assign(socket, :upload_errors, Map.put(socket.assigns.upload_errors, doc_type, err))}
        end

      [] ->
        {:noreply, socket}

      _ ->
        err = "Upload failed. Please try again."

        {:noreply,
         assign(socket, :upload_errors, Map.put(socket.assigns.upload_errors, doc_type, err))}
    end
  end

  @impl true
  def handle_event("submit_documents", _params, socket) do
    uploaded = socket.assigns.uploaded_docs
    missing = Enum.filter(@required_doc_types, fn type -> !Map.has_key?(uploaded, type) end)

    if missing == [] do
      {:noreply, advance_step(socket)}
    else
      labels = Enum.map_join(missing, ", ", &doc_label/1)
      {:noreply, assign(socket, :error, "Please upload required documents: #{labels}")}
    end
  end

  # ── Terms ─────────────────────────────────────────────────────────────────

  @impl true
  def handle_event("update_terms_form", %{"title" => title}, socket) do
    {:noreply, assign(socket, :accepted_by_title, title)}
  end

  @impl true
  def handle_event("toggle_terms", _params, socket) do
    {:noreply, assign(socket, :terms_accepted, !socket.assigns.terms_accepted)}
  end

  @impl true
  def handle_event("submit_terms", _params, socket) do
    unless socket.assigns.terms_accepted do
      {:noreply, assign(socket, :error, "You must accept the terms and conditions to continue.")}
    else
      user = socket.assigns.user

      command = %AcceptTerms{
        user_id: user.id,
        org_id: user.org_id,
        terms_version: @terms_version,
        accepted_by_name: user.name,
        accepted_by_title: socket.assigns.accepted_by_title,
        accepted_at: DateTime.utc_now()
      }

      case Nexus.App.dispatch(command,
             metadata: %{"idempotency_key" => "terms:#{user.id}"}
           ) do
        :ok ->
          {:noreply, advance_step(socket)}

        {:error, reason} ->
          Logger.error("[OnboardingUI] AcceptTerms failed: #{inspect(reason)}")

          {:noreply,
           assign(socket, :error, "Failed to record terms acceptance. Please try again.")}
      end
    end
  end

  # ── Biometric ─────────────────────────────────────────────────────────────

  @impl true
  def handle_event("back_to_welcome", _params, socket) do
    {:noreply, assign(socket, step: :welcome, status: :idle, error: nil)}
  end

  @impl true
  def handle_event("biometric_start", _params, socket) do
    user = socket.assigns[:user]

    if user do
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
      {:noreply,
       socket |> put_flash(:error, "Session expired. Please reload.") |> push_navigate(to: "/")}
    end
  end

  @impl true
  def handle_event("biometric_complete", %{"attestation" => attestation}, socket) do
    try do
      case WebAuthn.register_finish(attestation, socket.assigns.user_id, socket.assigns.user_id) do
        {:ok, %{auth_data: %{credential_id: credential_id, cose_key: cose_key}}} ->
          enroll_credential(credential_id, cose_key, socket)

        {:error, reason} ->
          Logger.error("[OnboardingUI] Attestation failed: #{inspect(reason)}")
          {:noreply, assign(socket, status: :error, error: format_webauthn_error(reason))}
      end
    rescue
      err ->
        Logger.error("[OnboardingUI] Biometric crash: #{inspect(err)}")

        {:noreply,
         socket
         |> assign(:status, :error)
         |> assign(:error, "Hardware handshake failed. Please try again.")}
    end
  end

  @impl true
  def handle_event("biometric_error", %{"reason" => reason}, socket) do
    clean_reason =
      if String.contains?(reason, "focus"),
        do: "Security focus lost: Please click the scanner directly.",
        else: "Handshake failed: #{reason}"

    {:noreply, socket |> assign(:status, :error) |> assign(:error, clean_reason)}
  end

  # ── Render ────────────────────────────────────────────────────────────────

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
        class="w-full max-w-[520px] prestige-card rounded-[2.5rem] relative overflow-hidden"
      >
        <%!-- Progress bar --%>
        <div class="flex gap-1.5 p-8 pb-0">
          <%= for {s, idx} <- Enum.with_index(@steps) do %>
            <span class={[
              "h-1 rounded-full transition-all duration-500",
              @step == s && "w-10 bg-emerald-400 shadow-[0_0_15px_rgba(52,211,153,0.9)]",
              @step != s && idx < step_index(@steps, @step) && "w-4 bg-emerald-400/40",
              @step != s && idx >= step_index(@steps, @step) && "w-4 bg-white/10"
            ]}>
            </span>
          <% end %>
        </div>

        <div class="px-7 pb-10 pt-5 min-h-[560px] flex flex-col justify-center">
          <%= case @step do %>
            <% :welcome -> %>
              <.welcome_step user={@user} status={@status} />
            <% :entity_details -> %>
              <.entity_details_step form={@entity_form} errors={@entity_errors} error={@error} />
            <% :ubos -> %>
              <.ubos_step ubos={@ubos} error={@error} />
            <% :documents -> %>
              <.documents_step
                uploads={@uploads}
                uploaded_docs={@uploaded_docs}
                upload_errors={@upload_errors}
                error={@error}
              />
            <% :terms -> %>
              <.terms_step
                user={@user}
                accepted={@terms_accepted}
                title={@accepted_by_title}
                error={@error}
              />
            <% :biometric -> %>
              <.biometric_step status={@status} error={@error} />
            <% :holding -> %>
              <.holding_step user={@user} />
          <% end %>
        </div>

        <div class="border-t border-white/5 px-7 py-5 flex items-center justify-between text-white/30 text-[8px] font-mono tracking-widest">
          <span>EQUINOX · INSTITUTIONAL KYB</span>
          <span>REGULATED PLATFORM</span>
        </div>
      </div>
    </div>
    """
  end

  # ── Step Components ───────────────────────────────────────────────────────

  attr :user, :any, required: true
  attr :status, :atom, required: true

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
          Complete your onboarding to access the platform
        </p>
      </div>

      <%= if @user do %>
        <div class="space-y-3 mb-4">
          <%= for {label, value, color} <- [
            {"Name", @user.name, "text-white/90"},
            {"Email", @user.email, "text-white/80"},
            {"Role", @user.role, "text-emerald-400 uppercase tracking-widest"}
          ] do %>
            <div class="group relative flex justify-between items-center p-5 bg-white/[0.03] border border-white/[0.06] rounded-2xl opacity-0">
              <div class="grid-guide-v left-10"></div>
              <div class="grid-guide-h top-0"></div>
              <div class="grid-guide-h bottom-0"></div>
              <span class="text-[9px] font-mono text-zinc-600 uppercase tracking-[0.25em]">
                {label}
              </span>
              <span class={"text-[11px] font-mono font-bold #{color}"}>{value}</span>
            </div>
          <% end %>
        </div>

        <button
          phx-click="next_step"
          class="cta-primary w-full py-5 bg-emerald-400 text-black rounded-full text-[10px] font-black uppercase tracking-[0.3em] flex items-center justify-center gap-3 shadow-[0_10px_30px_rgba(52,211,153,0.1)]"
        >
          <span class="relative z-10 flex items-center gap-3">
            Begin Onboarding
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

  attr :form, :map, required: true
  attr :errors, :map, required: true
  attr :error, :any, required: true

  defp entity_details_step(assigns) do
    ~H"""
    <div class="flex flex-col space-y-4">
      <div>
        <h2 class="text-2xl font-serif font-bold text-white mb-1">Entity Profile</h2>
        <p class="text-[9px] font-mono text-zinc-500 uppercase tracking-[0.2em]">
          Legal entity information for KYB verification
        </p>
      </div>

      <.error_banner error={@error} />

      <form phx-submit="submit_entity_profile" phx-change="update_entity" class="space-y-3">
        <input type="hidden" name="entity[__noop]" value="1" />

        <.field_input
          label="Legal Entity Name"
          name="entity[legal_name]"
          value={@form["legal_name"]}
          placeholder="Acme Treasury Ltd."
          error={@errors["legal_name"]}
        />

        <div class="grid grid-cols-2 gap-3">
          <.field_input
            label="Country (ISO 2)"
            name="entity[country]"
            value={@form["country"]}
            placeholder="GB"
            error={@errors["country"]}
          />
          <.field_input
            label="Industry"
            name="entity[industry]"
            value={@form["industry"]}
            placeholder="Financial Services"
            error={@errors["industry"]}
          />
        </div>

        <.field_input
          label="Registration Number"
          name="entity[registration_number]"
          value={@form["registration_number"]}
          placeholder="12345678"
          error={@errors["registration_number"]}
        />

        <.field_input
          label="Registered Address"
          name="entity[registered_address]"
          value={@form["registered_address"]}
          placeholder="123 Finance St, London EC2A 4BQ"
          error={@errors["registered_address"]}
        />

        <.field_input
          label="Tax ID (optional)"
          name="entity[tax_id]"
          value={@form["tax_id"]}
          placeholder="GB123456789"
          error={nil}
        />

        <button
          type="submit"
          class="cta-primary w-full mt-2 py-4 bg-emerald-400 text-black rounded-full text-[10px] font-black uppercase tracking-[0.3em] flex items-center justify-center gap-3"
        >
          Save & Continue <.icon name="hero-arrow-right" class="w-4 h-4" />
        </button>
      </form>
    </div>
    """
  end

  attr :ubos, :list, required: true
  attr :error, :any, required: true

  defp ubos_step(assigns) do
    ~H"""
    <div class="flex flex-col space-y-4">
      <div>
        <h2 class="text-2xl font-serif font-bold text-white mb-1">Beneficial Owners</h2>
        <p class="text-[9px] font-mono text-zinc-500 uppercase tracking-[0.2em]">
          Declare all individuals owning &gt;25% of the entity
        </p>
      </div>

      <.error_banner error={@error} />

      <form phx-submit="submit_ubos" phx-change="update_ubos_form" class="space-y-3">
        <input type="hidden" name="ubos[__noop]" value="1" />

        <%= for {ubo, idx} <- Enum.with_index(@ubos) do %>
          <div class="p-4 bg-white/[0.03] border border-white/[0.08] rounded-2xl space-y-3">
            <div class="flex items-center justify-between">
              <span class="text-[9px] font-mono text-emerald-400 uppercase tracking-widest">
                UBO #{idx + 1}
              </span>
              <%= if length(@ubos) > 1 do %>
                <button
                  type="button"
                  phx-click="remove_ubo"
                  phx-value-index={idx}
                  class="text-rose-400/60 hover:text-rose-400 text-[9px] font-mono uppercase tracking-widest transition-colors"
                >
                  Remove
                </button>
              <% end %>
            </div>

            <div class="grid grid-cols-2 gap-2">
              <div>
                <label class="text-[8px] font-mono text-zinc-600 uppercase tracking-widest block mb-1">
                  Full Name
                </label>
                <input
                  type="text"
                  name={"ubos[#{idx}][name]"}
                  value={ubo["name"]}
                  placeholder="Jane Smith"
                  class="w-full bg-white/[0.04] border border-white/10 rounded-xl px-3 py-2 text-[11px] font-mono text-white/90 placeholder-zinc-700 focus:outline-none focus:border-emerald-400/40"
                />
              </div>
              <div>
                <label class="text-[8px] font-mono text-zinc-600 uppercase tracking-widest block mb-1">
                  Nationality
                </label>
                <input
                  type="text"
                  name={"ubos[#{idx}][nationality]"}
                  value={ubo["nationality"]}
                  placeholder="British"
                  class="w-full bg-white/[0.04] border border-white/10 rounded-xl px-3 py-2 text-[11px] font-mono text-white/90 placeholder-zinc-700 focus:outline-none focus:border-emerald-400/40"
                />
              </div>
            </div>

            <div>
              <label class="text-[8px] font-mono text-zinc-600 uppercase tracking-widest block mb-1">
                Ownership %
              </label>
              <input
                type="number"
                min="25"
                max="100"
                name={"ubos[#{idx}][ownership_percent]"}
                value={ubo["ownership_percent"]}
                placeholder="51"
                class="w-full bg-white/[0.04] border border-white/10 rounded-xl px-3 py-2 text-[11px] font-mono text-white/90 placeholder-zinc-700 focus:outline-none focus:border-emerald-400/40"
              />
            </div>
          </div>
        <% end %>

        <button
          type="button"
          phx-click="add_ubo"
          class="w-full py-3 border border-dashed border-white/10 rounded-xl text-[9px] font-mono text-zinc-500 uppercase tracking-widest hover:border-emerald-400/30 hover:text-emerald-400/60 transition-all"
        >
          + Add Beneficial Owner
        </button>

        <button
          type="submit"
          class="cta-primary w-full py-4 bg-emerald-400 text-black rounded-full text-[10px] font-black uppercase tracking-[0.3em] flex items-center justify-center gap-3"
        >
          Confirm & Continue <.icon name="hero-arrow-right" class="w-4 h-4" />
        </button>
      </form>
    </div>
    """
  end

  attr :uploads, :map, required: true
  attr :uploaded_docs, :map, required: true
  attr :upload_errors, :map, required: true
  attr :error, :any, required: true

  defp documents_step(assigns) do
    ~H"""
    <div class="flex flex-col space-y-4">
      <div>
        <h2 class="text-2xl font-serif font-bold text-white mb-1">KYB Documents</h2>
        <p class="text-[9px] font-mono text-zinc-500 uppercase tracking-[0.2em]">
          Upload verification documents · PDF, JPG, PNG · max 20 MB
        </p>
      </div>

      <.error_banner error={@error} />

      <div class="space-y-3">
        <.doc_row
          doc_type="certificate_of_incorporation"
          label="Certificate of Incorporation"
          required={true}
          upload={@uploads.cert_of_inc}
          uploaded_doc={Map.get(@uploaded_docs, "certificate_of_incorporation")}
          upload_error={Map.get(@upload_errors, "certificate_of_incorporation")}
        />
        <.doc_row
          doc_type="proof_of_address"
          label="Proof of Business Address"
          required={true}
          upload={@uploads.proof_addr}
          uploaded_doc={Map.get(@uploaded_docs, "proof_of_address")}
          upload_error={Map.get(@upload_errors, "proof_of_address")}
        />
        <.doc_row
          doc_type="memorandum_of_association"
          label="Memorandum & Articles of Association"
          required={false}
          upload={@uploads.memo_of_assoc}
          uploaded_doc={Map.get(@uploaded_docs, "memorandum_of_association")}
          upload_error={Map.get(@upload_errors, "memorandum_of_association")}
        />
        <.doc_row
          doc_type="shareholder_register"
          label="Shareholder Register"
          required={false}
          upload={@uploads.shareholder_reg}
          uploaded_doc={Map.get(@uploaded_docs, "shareholder_register")}
          upload_error={Map.get(@upload_errors, "shareholder_register")}
        />
      </div>

      <button
        phx-click="submit_documents"
        class="cta-primary w-full py-4 bg-emerald-400 text-black rounded-full text-[10px] font-black uppercase tracking-[0.3em] flex items-center justify-center gap-3"
      >
        Continue <.icon name="hero-arrow-right" class="w-4 h-4" />
      </button>
    </div>
    """
  end

  attr :user, :any, required: true
  attr :accepted, :boolean, required: true
  attr :title, :string, required: true
  attr :error, :any, required: true

  defp terms_step(assigns) do
    ~H"""
    <div class="flex flex-col space-y-4">
      <div>
        <h2 class="text-2xl font-serif font-bold text-white mb-1">Terms & Conditions</h2>
        <p class="text-[9px] font-mono text-zinc-500 uppercase tracking-[0.2em]">
          Platform Terms of Service · Version V2026-01
        </p>
      </div>

      <.error_banner error={@error} />

      <div class="max-h-40 overflow-y-auto bg-white/[0.03] border border-white/[0.06] rounded-2xl p-4 text-[10px] text-zinc-400 font-mono space-y-2">
        <p>
          <strong class="text-white/80">1. Platform Access.</strong>
          Access to the Equinox Treasury Platform is granted solely for institutional treasury management purposes as described in your executed master service agreement.
        </p>
        <p>
          <strong class="text-white/80">2. Regulatory Compliance.</strong>
          All users must comply with applicable AML, KYC, and KYB regulations in their jurisdiction.
        </p>
        <p>
          <strong class="text-white/80">3. Data Obligations.</strong>
          You represent that all information submitted during onboarding is accurate, complete, and current. False statements may result in immediate access revocation.
        </p>
        <p>
          <strong class="text-white/80">4. Confidentiality.</strong>
          Platform data, transaction history, and counterparty information are strictly confidential. Unauthorized disclosure is prohibited.
        </p>
        <p>
          <strong class="text-white/80">5. Acceptable Use.</strong>
          The platform may not be used for personal transactions, sanctions evasion, tax fraud, or any activity violating applicable law.
        </p>
        <p>
          <strong class="text-white/80">6. Electronic Signature.</strong>
          By accepting these terms and completing biometric enrollment, you agree that your authenticated actions constitute a legally binding electronic signature.
        </p>
      </div>

      <form phx-change="update_terms_form" class="space-y-3">
        <div>
          <label class="text-[8px] font-mono text-zinc-600 uppercase tracking-widest block mb-1">
            Your Title / Role
          </label>
          <input
            type="text"
            name="title"
            value={@title}
            placeholder="Chief Financial Officer"
            class="w-full bg-white/[0.04] border border-white/10 rounded-xl px-3 py-2.5 text-[11px] font-mono text-white/90 placeholder-zinc-700 focus:outline-none focus:border-emerald-400/40"
          />
        </div>
      </form>

      <label class="flex items-start gap-3 cursor-pointer group">
        <button
          phx-click="toggle_terms"
          class={[
            "mt-0.5 w-5 h-5 flex-shrink-0 rounded border flex items-center justify-center transition-all",
            @accepted && "bg-emerald-400 border-emerald-400",
            !@accepted && "bg-transparent border-white/20 group-hover:border-emerald-400/40"
          ]}
        >
          <%= if @accepted do %>
            <.icon name="hero-check" class="w-3 h-3 text-black" />
          <% end %>
        </button>
        <span class="text-[10px] font-mono text-zinc-400">
          I, <strong class="text-white/80">{@user && @user.name}</strong>, have read and agree to the Equinox Platform Terms of Service v2026-01 and confirm all entity information provided is accurate.
        </span>
      </label>

      <button
        phx-click="submit_terms"
        disabled={!@accepted}
        class={[
          "cta-primary w-full py-4 rounded-full text-[10px] font-black uppercase tracking-[0.3em] flex items-center justify-center gap-3 transition-all",
          @accepted && "bg-emerald-400 text-black shadow-[0_10px_30px_rgba(52,211,153,0.1)]",
          !@accepted && "bg-white/10 text-white/30 cursor-not-allowed"
        ]}
      >
        Accept & Continue <.icon name="hero-arrow-right" class="w-4 h-4" />
      </button>
    </div>
    """
  end

  attr :status, :atom, required: true
  attr :error, :any, required: true

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
      </div>
    <% else %>
      <div class="flex flex-col items-center">
        <h2 class="text-2xl font-serif font-bold uppercase tracking-wide text-white">
          Identity Anchor
        </h2>
        <p class="text-[9px] text-zinc-500 mt-2 font-mono uppercase tracking-[0.25em]">
          Liveness 3.0 · Press & Hold
        </p>

        <div class="relative my-10 flex justify-center items-center">
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
      </div>
    <% end %>
    """
  end

  attr :user, :any, required: true

  defp holding_step(assigns) do
    ~H"""
    <div class="flex flex-col items-center text-center space-y-6 py-4">
      <div class="w-20 h-20 rounded-2xl bg-amber-400/10 flex items-center justify-center border border-amber-400/20">
        <.icon name="hero-clock" class="w-10 h-10 text-amber-400" />
      </div>

      <div>
        <h1 class="text-3xl font-serif italic font-black tracking-tight text-white mb-2">
          Under<br /><span class="text-amber-400">Review.</span>
        </h1>
        <p class="text-[9px] font-mono text-zinc-500 uppercase tracking-[0.2em]">
          Your KYB application is being processed
        </p>
      </div>

      <div class="w-full space-y-2 text-left">
        <div class="flex items-center gap-4 p-4 bg-white/[0.03] border border-white/[0.06] rounded-xl">
          <div class="w-8 h-8 rounded-lg bg-emerald-400/10 flex items-center justify-center shrink-0">
            <.icon name="hero-check-circle" class="w-4 h-4 text-emerald-400" />
          </div>
          <div>
            <p class="text-[10px] font-mono font-bold text-white/80 uppercase tracking-widest">
              Entity Profile
            </p>
            <p class="text-[9px] font-mono text-zinc-600 mt-0.5">Submitted & locked</p>
          </div>
          <span class="ml-auto text-[9px] font-mono text-emerald-400 uppercase tracking-widest">
            DONE
          </span>
        </div>

        <div class="flex items-center gap-4 p-4 bg-white/[0.03] border border-white/[0.06] rounded-xl">
          <div class="w-8 h-8 rounded-lg bg-emerald-400/10 flex items-center justify-center shrink-0">
            <.icon name="hero-check-circle" class="w-4 h-4 text-emerald-400" />
          </div>
          <div>
            <p class="text-[10px] font-mono font-bold text-white/80 uppercase tracking-widest">
              Identity Biometric
            </p>
            <p class="text-[9px] font-mono text-zinc-600 mt-0.5">Hardware-bound credential</p>
          </div>
          <span class="ml-auto text-[9px] font-mono text-emerald-400 uppercase tracking-widest">
            DONE
          </span>
        </div>

        <div class="flex items-center gap-4 p-4 bg-amber-400/5 border border-amber-400/20 rounded-xl">
          <div class="w-8 h-8 rounded-lg bg-amber-400/10 flex items-center justify-center shrink-0">
            <.icon name="hero-clock" class="w-4 h-4 text-amber-400" />
          </div>
          <div>
            <p class="text-[10px] font-mono font-bold text-white/80 uppercase tracking-widest">
              KYB Review
            </p>
            <p class="text-[9px] font-mono text-zinc-600 mt-0.5">Platform compliance team</p>
          </div>
          <span class="ml-auto text-[9px] font-mono text-amber-400 uppercase tracking-widest animate-pulse">
            PENDING
          </span>
        </div>
      </div>

      <p class="text-[10px] text-zinc-500 font-mono max-w-xs">
        Our compliance team reviews applications within 1–2 business days. You will receive an email when your account is activated.
      </p>
    </div>
    """
  end

  # ── Sub-components ────────────────────────────────────────────────────────

  attr :error, :any, required: true

  defp error_banner(assigns) do
    ~H"""
    <%= if @error do %>
      <div class="p-3 bg-rose-400/10 border border-rose-400/20 rounded-xl text-[10px] font-mono text-rose-400">
        {@error}
      </div>
    <% end %>
    """
  end

  attr :label, :string, required: true
  attr :name, :string, required: true
  attr :value, :string, required: true
  attr :placeholder, :string, required: true
  attr :error, :any, required: true

  defp field_input(assigns) do
    ~H"""
    <div>
      <label class="text-[8px] font-mono text-zinc-600 uppercase tracking-widest block mb-1">
        {@label}
      </label>
      <input
        type="text"
        name={@name}
        value={@value}
        placeholder={@placeholder}
        class={[
          "w-full bg-white/[0.04] border rounded-xl px-3 py-2.5 text-[11px] font-mono text-white/90 placeholder-zinc-700 focus:outline-none focus:border-emerald-400/40",
          @error && "border-rose-400/40",
          !@error && "border-white/10"
        ]}
      />
      <%= if @error do %>
        <p class="text-[9px] font-mono text-rose-400 mt-1">{@error}</p>
      <% end %>
    </div>
    """
  end

  attr :doc_type, :string, required: true
  attr :label, :string, required: true
  attr :required, :boolean, required: true
  attr :upload, :map, required: true
  attr :uploaded_doc, :any, required: true
  attr :upload_error, :any, required: true

  defp doc_row(assigns) do
    ~H"""
    <div class="p-4 bg-white/[0.03] border border-white/[0.06] rounded-2xl">
      <div class="flex items-center justify-between mb-3">
        <div class="flex items-center gap-2">
          <span class="text-[10px] font-mono font-bold text-white/80">{@label}</span>
          <%= if @required do %>
            <span class="text-[8px] font-mono text-rose-400 uppercase tracking-widest">Required</span>
          <% else %>
            <span class="text-[8px] font-mono text-zinc-600 uppercase tracking-widest">Optional</span>
          <% end %>
        </div>
        <%= if @uploaded_doc do %>
          <span class="text-[9px] font-mono text-emerald-400">✓ Uploaded</span>
        <% end %>
      </div>

      <%= if @uploaded_doc do %>
        <p class="text-[9px] font-mono text-zinc-500 truncate">{@uploaded_doc.file_name}</p>
      <% else %>
        <form phx-submit="upload_doc" phx-change="validate_doc">
          <input type="hidden" name="doc_type" value={@doc_type} />
          <.live_file_input upload={@upload} class="sr-only" />
          <div class="flex gap-2">
            <label
              for={@upload.ref}
              class="flex-1 py-2.5 text-center border border-dashed border-white/10 rounded-xl text-[9px] font-mono text-zinc-500 uppercase tracking-widest cursor-pointer hover:border-emerald-400/30 hover:text-emerald-400/60 transition-all"
            >
              <%= if Enum.any?(@upload.entries) do %>
                {List.first(@upload.entries).client_name}
              <% else %>
                Select File
              <% end %>
            </label>
            <button
              type="submit"
              disabled={Enum.empty?(@upload.entries)}
              class={[
                "px-4 py-2.5 rounded-xl text-[9px] font-mono uppercase tracking-widest transition-all font-bold",
                Enum.any?(@upload.entries) && "bg-emerald-400 text-black",
                Enum.empty?(@upload.entries) && "bg-white/5 text-white/20 cursor-not-allowed"
              ]}
            >
              Upload
            </button>
          </div>
        </form>
        <%= if @upload_error do %>
          <p class="text-[9px] font-mono text-rose-400 mt-2">{@upload_error}</p>
        <% end %>
      <% end %>
    </div>
    """
  end

  # ── Private Helpers ───────────────────────────────────────────────────────

  defp build_steps(nil), do: [:welcome, :terms, :biometric]

  defp build_steps(%{role: role}) when role in @entity_admin_roles do
    [:welcome, :entity_details, :ubos, :documents, :terms, :biometric, :holding]
  end

  defp build_steps(_user), do: [:welcome, :terms, :biometric]

  defp step_index(steps, current_step) do
    Enum.find_index(steps, fn s -> s == current_step end) || 0
  end

  defp advance_step(socket) do
    steps = socket.assigns.steps
    current_idx = step_index(steps, socket.assigns.step)
    next = Enum.at(steps, current_idx + 1)
    if next, do: assign(socket, step: next, error: nil, status: :idle), else: socket
  end

  defp go_back(socket) do
    steps = socket.assigns.steps
    current_idx = step_index(steps, socket.assigns.step)
    prev = Enum.at(steps, current_idx - 1)
    if prev, do: assign(socket, step: prev, error: nil), else: socket
  end

  defp blank_ubo, do: %{"name" => "", "nationality" => "", "ownership_percent" => ""}

  defp validate_entity_form(form) do
    ~w(legal_name country registration_number registered_address industry)
    |> Enum.reduce(%{}, fn field, errors ->
      if form[field] == nil || String.trim(form[field]) == "" do
        Map.put(errors, field, "Required")
      else
        errors
      end
    end)
  end

  defp doc_type_to_upload_key("certificate_of_incorporation"), do: :cert_of_inc
  defp doc_type_to_upload_key("proof_of_address"), do: :proof_addr
  defp doc_type_to_upload_key("memorandum_of_association"), do: :memo_of_assoc
  defp doc_type_to_upload_key("shareholder_register"), do: :shareholder_reg

  defp doc_label("certificate_of_incorporation"), do: "Certificate of Incorporation"
  defp doc_label("proof_of_address"), do: "Proof of Business Address"
  defp doc_label(t), do: t

  defp enroll_credential(credential_id, cose_key, socket) do
    command = %EnrollBiometric{
      user_id: socket.assigns.user_id,
      org_id: socket.assigns.user.org_id,
      credential_id: Base.encode64(credential_id, padding: false),
      cose_key: Base.encode64(:erlang.term_to_binary(cose_key), padding: false)
    }

    case Nexus.App.dispatch(command,
           metadata: %{"idempotency_key" => socket.assigns.user_id}
         ) do
      result when result == :ok or (is_tuple(result) and elem(result, 0) == :ok) ->
        Logger.info("[OnboardingUI] Identity anchored for #{socket.assigns.user_id}")

        if :holding in socket.assigns.steps do
          {:noreply, assign(socket, step: :holding, status: :complete)}
        else
          {:noreply,
           socket |> assign(:status, :complete) |> push_navigate(to: ~p"/onboarding/success")}
        end

      {:error, reason} ->
        Logger.error("[OnboardingUI] EnrollBiometric failed: #{inspect(reason)}")
        {:noreply, assign(socket, status: :error, error: "Command failed: #{inspect(reason)}")}
    end
  end

  defp format_webauthn_error(%Wax.InvalidClientDataError{reason: :origin_mismatch}) do
    "Address mismatch: Please ensure you are using the same URL that provided your invitation."
  end

  defp format_webauthn_error(reason), do: "Verification failed: #{inspect(reason)}"
end
