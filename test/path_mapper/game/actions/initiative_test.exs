defmodule PathMapper.Game.Actions.InitiativeTest do
  use ExUnit.Case, async: true

  alias PathMapper.Game.Actions.Initiative
  alias PathMapper.Game.State

  defp state(initiative \\ []) do
    %State{initiative: initiative}
  end

  describe "add" do
    test "adds entry to empty list" do
      {:ok, new_state} =
        Initiative.action(state(), [:initiative, :add], %{
          name: "Goblin",
          value: 15,
          owner: "enemy"
        })

      assert length(new_state.initiative) == 1
      [entry] = new_state.initiative
      assert entry.name == "Goblin"
      assert entry.value == 15
      assert entry.owner == "enemy"
      assert is_binary(entry.id)
    end

    test "inserts sorted descending" do
      {:ok, s1} =
        Initiative.action(state(), [:initiative, :add], %{name: "A", value: 10, owner: "enemy"})

      {:ok, s2} =
        Initiative.action(s1, [:initiative, :add], %{name: "B", value: 20, owner: "enemy"})

      {:ok, s3} =
        Initiative.action(s2, [:initiative, :add], %{name: "C", value: 15, owner: "enemy"})

      names = Enum.map(s3.initiative, & &1.name)
      assert names == ["B", "C", "A"]
    end

    test "ties preserve insertion order" do
      {:ok, s1} =
        Initiative.action(state(), [:initiative, :add], %{
          name: "First",
          value: 10,
          owner: "enemy"
        })

      {:ok, s2} =
        Initiative.action(s1, [:initiative, :add], %{name: "Second", value: 10, owner: "enemy"})

      names = Enum.map(s2.initiative, & &1.name)
      assert names == ["First", "Second"]
    end

    test "upserts player entries by owner" do
      {:ok, s1} =
        Initiative.action(state(), [:initiative, :add], %{
          name: "Alice",
          value: 10,
          owner: "Alice"
        })

      {:ok, s2} =
        Initiative.action(s1, [:initiative, :add], %{name: "Alice", value: 18, owner: "Alice"})

      assert length(s2.initiative) == 1
      [entry] = s2.initiative
      assert entry.value == 18
    end

    test "does not upsert enemy entries" do
      {:ok, s1} =
        Initiative.action(state(), [:initiative, :add], %{
          name: "Goblin 1",
          value: 12,
          owner: "enemy"
        })

      {:ok, s2} =
        Initiative.action(s1, [:initiative, :add], %{name: "Goblin 2", value: 8, owner: "enemy"})

      assert length(s2.initiative) == 2
    end

    test "does not upsert npc entries" do
      {:ok, s1} =
        Initiative.action(state(), [:initiative, :add], %{name: "Guard", value: 14, owner: "npc"})

      {:ok, s2} =
        Initiative.action(s1, [:initiative, :add], %{name: "Merchant", value: 5, owner: "npc"})

      assert length(s2.initiative) == 2
    end
  end

  describe "remove" do
    test "removes entry by id" do
      {:ok, s1} =
        Initiative.action(state(), [:initiative, :add], %{name: "A", value: 10, owner: "enemy"})

      [entry] = s1.initiative
      {:ok, s2} = Initiative.action(s1, [:initiative, :remove], entry.id)

      assert s2.initiative == []
    end

    test "no-op for unknown id" do
      {:ok, s1} =
        Initiative.action(state(), [:initiative, :add], %{name: "A", value: 10, owner: "enemy"})

      {:ok, s2} = Initiative.action(s1, [:initiative, :remove], "nonexistent")

      assert length(s2.initiative) == 1
    end
  end

  describe "reset" do
    test "clears all entries" do
      {:ok, s1} =
        Initiative.action(state(), [:initiative, :add], %{name: "A", value: 10, owner: "enemy"})

      {:ok, s2} =
        Initiative.action(s1, [:initiative, :add], %{name: "B", value: 20, owner: "npc"})

      {:ok, s3} = Initiative.action(s2, [:initiative, :reset], nil)

      assert s3.initiative == []
    end
  end
end
