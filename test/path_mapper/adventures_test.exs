defmodule PathMapper.ScenesTest do
  use ExUnit.Case

  alias PathMapper.Adventures.Adventure

  test "loads an adventure" do
    {:ok, %Adventure{}} = PathMapper.Adventures.load_adventure("adventure.zip")
  end
end
