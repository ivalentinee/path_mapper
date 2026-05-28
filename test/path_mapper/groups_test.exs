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

  describe "reload/0" do
    test "updates Agent state with current directory contents" do
      original = Groups.get()
      Groups.reload()
      assert Groups.get() == original
    end

    test "broadcasts groups_list_updated event" do
      Groups.subscribe()
      Groups.reload()
      assert_receive %{groups_list_updated: filenames}
      assert is_list(filenames)
    end

    test "does not affect loaded group" do
      {:ok, group} = Groups.load_group("group-1.zip")
      Groups.reload()
      assert {:ok, ^group} = Groups.get_loaded()
    end
  end
end
