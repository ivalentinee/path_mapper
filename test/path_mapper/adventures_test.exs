defmodule PathMapper.ScenesTest do
  use ExUnit.Case

  alias PathMapper.Adventures

  test "loads an adventure" do
    assert {:ok, _adventure} = Adventures.load_adventure("adventure-1.zip")
  end
end
