defmodule GeminiCliSdkTest do
  use ExUnit.Case
  doctest GeminiCliSdk

  test "greets the world" do
    assert GeminiCliSdk.hello() == :world
  end
end
