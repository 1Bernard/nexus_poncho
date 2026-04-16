defmodule NexusSharedTest do
  use ExUnit.Case
  doctest NexusShared

  test "greets the world" do
    assert NexusShared.hello() == :world
  end
end
