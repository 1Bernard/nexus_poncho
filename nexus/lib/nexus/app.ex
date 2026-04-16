defmodule Nexus.App do
  @moduledoc """
  The Commanded application for Nexus.
  """
  use Commanded.Application, otp_app: :nexus

  router(Nexus.Router)
end
