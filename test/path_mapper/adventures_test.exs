defmodule PathMapper.ScenesTest do
  use ExUnit.Case

  alias PathMapper.Adventures
  alias PathMapper.Adventures.Adventure

  test "loads an adventure" do
    {:ok, %Adventure{}} = Adventures.load_adventure("adventure-1.zip")
    %Adventure{} = Adventures.get().loaded
  end
end
