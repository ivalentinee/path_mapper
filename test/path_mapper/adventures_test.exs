defmodule PathMapper.AdventuresTest do
  use ExUnit.Case

  alias PathMapper.Adventures

  test "loads an adventure" do
    assert {:ok, _adventure} = Adventures.load_adventure("adventure-1.zip")
  end

  describe "reload/0" do
    test "updates Agent state with current directory contents" do
      original = Adventures.get()
      Adventures.reload()
      assert Adventures.get() == original
    end

    test "broadcasts adventures_list_updated event" do
      Adventures.subscribe()
      Adventures.reload()
      assert_receive %{adventures_list_updated: filenames}
      assert is_list(filenames)
    end

    test "does not affect loaded adventure" do
      {:ok, adventure} = Adventures.load_adventure("adventure-1.zip")
      Adventures.reload()
      assert {:ok, ^adventure} = Adventures.get_loaded()
    end
  end
end
