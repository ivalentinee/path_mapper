defmodule PathMapper.ScenesTest do
  use ExUnit.Case

  alias PathMapper.Adventures
  alias PathMapper.Adventures.Adventure

  test "loads an adventure" do
    {:ok, %Adventure{}} = Adventures.load_adventure("adventure.zip")
    %Adventure{} = Adventures.get_loaded_adventure()
  end
end
