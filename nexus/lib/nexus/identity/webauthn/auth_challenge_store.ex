defmodule Nexus.Identity.WebAuthn.AuthChallengeStore do
  @moduledoc """
  A distributed, high-performance challenge store leveraging Mnesia.

  In a "Poncho" cluster, a user may generate a biometric challenge on Node A
  but submit the response to Node B. Local ETS would fail in this scenario.
  Mnesia provides "distributed RAM" that replicates challenges across the cluster,
  ensuring seamless authentication regardless of node locality.
  """

  require Logger

  @table :auth_challenges
  @ttl :timer.minutes(10)

  @type challenge_id :: String.t()
  @type challenge :: map() | binary()

  @doc """
  Stores a WebAuthn challenge with a distributed TTL.
  """
  def put(id, challenge) do
    if is_binary(challenge) do
      Logger.info("[AuthChallengeStore] Storing raw binary challenge for #{id}")
    else
      Logger.info("[AuthChallengeStore] Storing struct-based challenge for #{id}: #{inspect(Map.get(challenge, :__struct__, "Map"))}")
    end

    expiry = System.system_time(:millisecond) + @ttl
    
    case :mnesia.transaction(fn -> :mnesia.write({@table, id, challenge, expiry}) end) do
      {:atomic, :ok} -> :ok
      {:aborted, reason} -> 
        Logger.error("Failed to store auth challenge in Mnesia: #{inspect(reason)}")
        {:error, reason}
    end
  end

  @doc """
  Retrieves a challenge if it exists and has not expired.
  Automatically prunes the record if expired.
  """
  def get(id) do
    now = System.system_time(:millisecond)

    case :mnesia.transaction(fn -> :mnesia.read({@table, id}) end) do
      {:atomic, [{@table, ^id, challenge, expiry}]} ->
        if now < expiry do
          challenge
        else
          delete(id)
          nil
        end

      {:atomic, []} ->
        nil

      {:aborted, reason} ->
        Logger.error("Failed to read auth challenge from Mnesia: #{inspect(reason)}")
        nil
    end
  end

  @doc """
  Deletes a challenge from the distributed store.
  """
  def delete(id) do
    :mnesia.transaction(fn -> :mnesia.delete({@table, id}) end)
    :ok
  end

  @doc """
  Performs table maintenance, deleting all expired challenges.
  """
  def prune_expired do
    now = System.system_time(:millisecond)
    
    # Using a match spec for efficiency
    match_spec = [{{@table, :"$1", :"$2", :"$3"}, [{:<, :"$3", now}], [:"$1"]}]
    
    case :mnesia.transaction(fn -> :mnesia.select(@table, match_spec) end) do
      {:atomic, expired_ids} ->
        Enum.each(expired_ids, &delete/1)
        {:ok, length(expired_ids)}
      {:aborted, reason} ->
        {:error, reason}
    end
  end
end
