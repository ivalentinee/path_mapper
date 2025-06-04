defmodule PathMapper.ScenesTest do
  use ExUnit.Case

  alias PathMapper.Adventures.Adventure.Scene.Map

  test "loads an adventure" do
    {:ok, %Map{}} = PathMapper.Adventures.load_adventure("sample.ora")
  end
end
