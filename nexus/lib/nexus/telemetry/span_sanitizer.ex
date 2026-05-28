defmodule Nexus.Telemetry.SpanSanitizer do
  @moduledoc false
  @behaviour :otel_span_processor

  require Record

  Record.defrecord(
    :otel_span,
    :span,
    Record.extract(:span, from_lib: "opentelemetry/include/otel_span.hrl")
  )

  @sensitive_params ~w(_csrf_token token)
  @disconnect_error "Unrecoverable error: closed"
  @url_query :"url.query"
  @error_type :"error.type"

  # Called when each span starts. Results are chained: our sanitized span is
  # what the batch processor stores, so the clean attributes persist to on_end.
  @doc false
  def on_start(_ctx, span_data, _config) do
    span_data
    |> sanitize_url_query()
    |> strip_nil_attributes()
  end

  # Called when each span ends with the final span state.
  # Returning :dropped short-circuits the processor chain — the batch processor
  # never sees the span and it is not exported to Tempo.
  @doc false
  def on_end(span_data, _config) do
    attr_map = span_data |> otel_span(:attributes) |> :otel_attributes.map()

    if Map.get(attr_map, @error_type) == @disconnect_error do
      :dropped
    else
      true
    end
  end

  @doc false
  def force_flush(_config), do: :ok

  # Overwrites url.query in the span before it is stored in ETS, replacing
  # sensitive Phoenix/LiveView params (_csrf_token, token) with redacted values.
  defp sanitize_url_query(span_data) do
    attrs = otel_span(span_data, :attributes)
    attr_map = :otel_attributes.map(attrs)

    case Map.get(attr_map, @url_query) do
      query when is_binary(query) and byte_size(query) > 0 ->
        sanitized = redact_params(query)
        new_attrs = :otel_attributes.set(@url_query, sanitized, attrs)
        otel_span(span_data, attributes: new_attrs)

      _ ->
        span_data
    end
  end

  # opentelemetry_ecto sets `source: nil` for queries with no table name
  # (raw SQL, EventStore queries). The OTel SDK stores nil atoms in the
  # attribute map rather than filtering them, causing "nil" strings in Tempo.
  defp strip_nil_attributes(span_data) do
    attrs = otel_span(span_data, :attributes)
    attr_map = :otel_attributes.map(attrs)
    clean_map = Map.reject(attr_map, fn {_k, v} -> is_nil(v) end)

    if map_size(clean_map) == map_size(attr_map) do
      span_data
    else
      new_attrs = :otel_attributes.new(clean_map, 128, :infinity)
      otel_span(span_data, attributes: new_attrs)
    end
  end

  defp redact_params(query_string) do
    query_string
    |> URI.decode_query()
    |> Map.drop(@sensitive_params)
    |> URI.encode_query()
  end
end
