defmodule PathMapper.Game.PaletteTest do
  use ExUnit.Case

  import PathMapperWeb.TestHelpers

  setup do
    PathMapper.Game.clear()
    :ok
  end

  alias PathMapper.Game.Palette

  describe "build/1" do
    test "builds defaults without group" do
      palette = Palette.build(nil)
      assert palette["enemy"] == "#db0909"
      assert palette["npc"] == "#a1a1a1"
      assert palette["none"] == nil
    end

    test "merges player colors from group" do
      {:ok, group} = load_group("tg0001-0000000001-group-1.zip")
      palette = Palette.build(group)

      player = Enum.at(group.players, 0)
      assert palette[player.id] == player.color
      assert palette["enemy"] == "#db0909"
    end
  end

  describe "resolve/1" do
    test "returns default colors for known owners" do
      Palette.build(nil) |> Palette.store()

      assert Palette.resolve("enemy") == "#db0909"
      assert Palette.resolve("npc") == "#a1a1a1"
    end

    test "returns black for unknown owners" do
      Palette.build(nil) |> Palette.store()

      assert Palette.resolve("unknown") == "#000000"
    end

    test "returns nil for none owner" do
      Palette.build(nil) |> Palette.store()

      assert Palette.resolve("none") == nil
    end

    test "returns player color when group is loaded" do
      {:ok, group} = load_group("tg0001-0000000001-group-1.zip")
      Palette.build(group) |> Palette.store()

      player = Enum.at(group.players, 0)
      assert Palette.resolve(player.id) == player.color
    end
  end
end
