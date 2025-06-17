defmodule PathMapper.GroupsTest do
  use ExUnit.Case

  alias PathMapper.Groups

  test "loads an group" do
    assert {:ok, _group} = Groups.load_group("group-1.zip")
  end
end
