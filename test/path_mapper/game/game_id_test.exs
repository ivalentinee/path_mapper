defmodule PathMapper.Game.GameIdTest do
  use ExUnit.Case, async: true

  alias PathMapper.Game.GameId

  @token "tk0001-0000000042"

  describe "mint/1" do
    test "begins with the token it places" do
      assert GameId.mint(@token) =~ ~r/^#{@token}-/
    end

    test "is not the token's own id" do
      refute GameId.mint(@token) == @token
    end

    test "differs every time, so two placements of one token differ" do
      ids = Enum.map(1..100, fn _ -> GameId.mint(@token) end)

      assert length(Enum.uniq(ids)) == 100
    end
  end

  describe "mint/2" do
    test "takes the suffix it is given" do
      assert GameId.mint(@token, "left-guard") == "#{@token}-left-guard"
    end

    # This is what places a player's own token once: the same inputs name the
    # same placement, so a second attempt collides rather than adding one.
    test "is the same id for the same suffix" do
      assert GameId.mint(@token, "pg0001-0000000001") ==
               GameId.mint(@token, "pg0001-0000000001")
    end
  end

  describe "token_id/1" do
    test "reads back the token a minted id places" do
      assert GameId.token_id(GameId.mint(@token)) == @token
    end

    test "reads back the token an authored id places" do
      assert GameId.token_id("#{@token}-left-guard") == @token
    end

    test "keeps a suffix that itself looks like an id" do
      assert GameId.token_id("#{@token}-tk0002-0000000001") == @token
    end

    test "is nil when nothing names a token" do
      assert GameId.token_id("left-guard") == nil
      assert GameId.token_id(@token) == nil
    end
  end
end
