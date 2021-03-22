defmodule BackofficeTest do
  use ExUnit.Case
  doctest Backoffice

  test "greets the world" do
    assert Backoffice.hello() == :world
  end
end
