defmodule PathMapper.Session.Map.MapObject.LinkTest do
  @moduledoc """
  The link grammar, which is a contract: a game master types it into a layer name
  in GIMP and saves it in their files, so its spelling cannot drift.
  """
  use ExUnit.Case, async: true

  alias PathMapper.Session.Map.MapObject
  alias PathMapper.Session.Map.MapObject.Link

  @target "mt0001-0000000002"

  describe "the three ways to write a property" do
    test "a bare word is present, which is true" do
      link = Link.parse("link nofollow #{@target}")

      assert link.properties == %{"nofollow" => true}
    end

    test "key=value carries a value with no whitespace" do
      link = Link.parse("link gocolor=aabbcc #{@target}")

      assert link.properties == %{"gocolor" => "aabbcc"}
    end

    test ~s|key="value" carries a value with whitespace| do
      link = Link.parse(~s|link title="Abandoned Castle" #{@target}|)

      assert link.title == "Abandoned Castle"
    end
  end

  describe "the target" do
    test "is the last word, and the only thing a link needs" do
      link = Link.parse("link #{@target}")

      assert link.target == @target
      assert link.properties == %{}
    end

    test "a tag with nothing after it is not a link" do
      assert Link.parse("link") == nil
    end

    # Otherwise `gm` would be read as the target, and the flag would vanish with it.
    test "a tag whose last word is not an id is not a link" do
      assert Link.parse("link gm") == nil
      assert Link.parse("link not-an-id") == nil
    end

    test "a tag that is not a link at all is not one" do
      assert Link.parse("hide") == nil
      assert Link.parse("floor-1") == nil
    end
  end

  describe "gm" do
    test "present means hidden from the player rendering" do
      assert Link.parse("link gm #{@target}").gm
    end

    test "absent means shown" do
      refute Link.parse("link #{@target}").gm
    end

    # A non-empty string is truthy in Elixir, so reading the property map directly
    # would hide a link its author had just un-hidden.
    test "gm=false is false, not the string \"false\"" do
      refute Link.parse("link gm=false #{@target}").gm
    end
  end

  describe "what this version does not understand" do
    test "is kept rather than refused" do
      link = Link.parse(~s|link gm nofollow gocolor=aabbcc title="A Keep" #{@target}|)

      assert link.gm
      assert link.title == "A Keep"
      assert link.properties == %{"nofollow" => true, "gocolor" => "aabbcc"}
    end
  end

  describe "through the object the tag is written on" do
    test "an object carrying a link tag arrives with it parsed" do
      object = cast(["link gm #{@target}"])

      assert object.link.target == @target
      assert object.link.gm
    end

    test "an object carrying none arrives with nothing" do
      assert cast(["hide"]).link == nil
    end

    test "a link is read beside show, and neither disturbs the other" do
      object = cast(["hide", "link #{@target}"])

      refute object.show
      assert object.link.target == @target
    end
  end

  defp cast(tags) do
    %MapObject{}
    |> MapObject.changeset(%{
      "name" => "Tavern",
      "image" => "x",
      "x" => 1,
      "y" => 2,
      "width" => 3,
      "height" => 4,
      "layer_index" => 1,
      "tags" => tags
    })
    |> Ecto.Changeset.apply_changes()
  end
end
