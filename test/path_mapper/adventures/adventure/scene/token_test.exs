defmodule PathMapper.Adventures.Adventure.Scene.TokenTest do
  use ExUnit.Case

  alias PathMapper.Adventures.Adventure.Scene.Token

  describe "color/1" do
    test "enemy returns red (case-insensitive)" do
      assert Token.color("enemy") == "#db0909"
      assert Token.color("Enemy") == "#db0909"
      assert Token.color("ENEMY") == "#db0909"
    end

    test "npc returns gray (case-insensitive)" do
      assert Token.color("npc") == "#a1a1a1"
      assert Token.color("NPC") == "#a1a1a1"
      assert Token.color("Npc") == "#a1a1a1"
    end

    test "unknown owner returns black" do
      assert Token.color("boss") == "#000000"
      assert Token.color("") == "#000000"
    end

    test "non-string returns black" do
      assert Token.color(nil) == "#000000"
    end
  end
end
