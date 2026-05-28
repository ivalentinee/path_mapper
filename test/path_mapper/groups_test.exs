defmodule PathMapper.GroupsTest do
  use ExUnit.Case

  alias PathMapper.Groups

  test "loads a group" do
    assert {:ok, group} = Groups.load_group("group-1.zip")
    assert length(group.players) == 2
  end

  test "parses class field when present" do
    {:ok, group} = Groups.load_group("group-1.zip")
    player_with_class = Enum.at(group.players, 0)
    assert player_with_class.class == "Fighter"
  end

  test "class is nil when absent" do
    {:ok, group} = Groups.load_group("group-1.zip")
    player_without_class = Enum.at(group.players, 1)
    assert player_without_class.class == nil
  end
end
