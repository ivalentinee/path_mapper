defmodule PathMapper.Game.PaletteTest do
  use ExUnit.Case

  import PathMapperWeb.TestHelpers

  setup do
    PathMapper.Game.clear()
    :ok
  end

  alias PathMapper.Game.Palette

  describe "build/1" do
    test "builds defaults with no characters" do
      palette = Palette.build(nil)
      assert palette["enemy"] == "#db0909"
      assert palette["npc"] == "#a1a1a1"
      assert palette["none"] == nil
    end

    test "merges character colours" do
      characters = load_party()
      palette = Palette.build(characters)

      character = Enum.at(characters, 0)
      assert palette[character.id] == character.color
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

    test "returns a character's colour once they are declared" do
      characters = load_party()
      Palette.build(characters) |> Palette.store()

      character = Enum.at(characters, 0)
      assert Palette.resolve(character.id) == character.color
    end
  end
end
