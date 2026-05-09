defmodule Nexus.Onboarding.Storage.DocumentStore do
  @moduledoc """
  S3-compatible document storage for KYB uploads.
  Delegates to ExAws.S3, pointed at ministack in dev and real AWS in prod.
  """

  require Logger

  @default_bucket "nexus-kyb-documents"

  @doc """
  Uploads binary content to S3.

  Returns `{:ok, file_key}` on success or `{:error, reason}` on failure.
  `file_key` is the path within the bucket (e.g. "kyb/org_id/cert_of_inc/uuid.pdf").
  """
  def upload(
        org_id,
        document_type,
        file_name,
        content,
        content_type \\ "application/octet-stream"
      ) do
    bucket = bucket()
    ext = Path.extname(file_name)
    key = "kyb/#{org_id}/#{document_type}/#{Uniq.UUID.uuid7()}#{ext}"

    opts = [
      content_type: content_type,
      acl: :private
    ]

    result =
      ExAws.S3.put_object(bucket, key, content, opts)
      |> ExAws.request()

    case result do
      {:ok, _} ->
        {:ok, key}

      {:error, reason} ->
        Logger.error(
          "[DocumentStore] Upload failed for #{org_id}/#{document_type}: #{inspect(reason)}"
        )

        {:error, reason}
    end
  end

  @doc """
  Generates a presigned GET URL valid for `expires_in` seconds (default 15 minutes).
  """
  def presigned_url(file_key, expires_in \\ 900) do
    config = ExAws.Config.new(:s3)

    ExAws.S3.presigned_url(config, :get, bucket(), file_key,
      expires_in: expires_in,
      virtual_host: false
    )
  end

  @doc """
  Deletes a document from S3. Used when a KYB submission is retracted.
  """
  def delete(file_key) do
    ExAws.S3.delete_object(bucket(), file_key)
    |> ExAws.request()
  end

  @doc """
  Ensures the KYB bucket exists. Called at application startup in dev.
  Safe to call multiple times — bucket creation is idempotent.
  """
  def ensure_bucket do
    case ExAws.S3.put_bucket(bucket(), "us-east-1") |> ExAws.request() do
      {:ok, _} ->
        :ok

      {:error, {:http_error, 409, _}} ->
        :ok

      {:error, reason} ->
        Logger.warning("[DocumentStore] Could not ensure bucket: #{inspect(reason)}")
        :ok
    end
  end

  defp bucket do
    System.get_env("S3_BUCKET") || @default_bucket
  end
end
