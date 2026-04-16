defmodule Nexus.EventStore do
  @moduledoc """
  The event store for the Nexus application.
  """
  use EventStore, otp_app: :nexus
end
