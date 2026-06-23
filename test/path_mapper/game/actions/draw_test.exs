defmodule PathMapper.Game.Actions.DrawTest do
  use ExUnit.Case, async: true

  alias PathMapper.Game.Actions
  alias PathMapper.Game.Actions.Draw
  alias PathMapper.Game.State
  alias PathMapper.Game.State.Scene

  defp state_with_scene do
    scene = Scene.initialize_custom("Test", 0)
    %State{active_scene: 0, scenes: %{0 => scene}}
  end

  defp add_element(state, opts \\ []) do
    Draw.action(state, [:draw, :add], %{
      type: opts[:type] || :fill,
      color: opts[:color] || "#ff0000",
      owner: opts[:owner] || "GM",
      data: opts[:data] || %{"x" => 1, "y" => 2}
    })
  end

  describe "[:draw, :add]" do
    test "adds an element with all fields" do
      {:ok, state} = add_element(state_with_scene())
      [element] = State.scene(state).drawn_elements

      assert element.id != nil
      assert element.type == :fill
      assert element.color == "#ff0000"
      assert element.owner == "GM"
      assert element.data == %{"x" => 1, "y" => 2}
    end

    test "supports all element types" do
      for type <- [:fill, :rect, :line, :circle, :text] do
        {:ok, _state} = add_element(state_with_scene(), type: type)
      end
    end

    test "preserves insertion order" do
      {:ok, state} = add_element(state_with_scene(), color: "#111111")
      {:ok, state} = add_element(state, color: "#222222")

      colors = Enum.map(State.scene(state).drawn_elements, & &1.color)
      assert colors == ["#111111", "#222222"]
    end
  end

  describe "[:draw, :remove]" do
    test "removes element by id" do
      {:ok, state} = add_element(state_with_scene())
      [element] = State.scene(state).drawn_elements

      {:ok, state} = Draw.action(state, [:draw, :remove], %{id: element.id, owner: "GM"})
      assert State.scene(state).drawn_elements == []
    end

    test "GM can erase player's element" do
      {:ok, state} = add_element(state_with_scene(), owner: "Alice")
      [element] = State.scene(state).drawn_elements

      {:ok, state} = Draw.action(state, [:draw, :remove], %{id: element.id, owner: "GM"})
      assert State.scene(state).drawn_elements == []
    end

    test "player can erase own element" do
      {:ok, state} = add_element(state_with_scene(), owner: "Alice")
      [element] = State.scene(state).drawn_elements

      {:ok, state} = Draw.action(state, [:draw, :remove], %{id: element.id, owner: "Alice"})
      assert State.scene(state).drawn_elements == []
    end

    test "player cannot erase another player's element" do
      {:ok, state} = add_element(state_with_scene(), owner: "Alice")
      [element] = State.scene(state).drawn_elements

      assert {:error, "Not authorized" <> _} =
               Draw.action(state, [:draw, :remove], %{id: element.id, owner: "Bob"})
    end

    test "player cannot erase GM's element" do
      {:ok, state} = add_element(state_with_scene(), owner: "GM")
      [element] = State.scene(state).drawn_elements

      assert {:error, "Not authorized" <> _} =
               Draw.action(state, [:draw, :remove], %{id: element.id, owner: "Alice"})
    end

    test "returns error for nonexistent id" do
      assert {:error, "Element not found"} =
               Draw.action(state_with_scene(), [:draw, :remove], %{
                 id: "nonexistent",
                 owner: "GM"
               })
    end
  end

  describe "[:draw, :clear]" do
    test "GM clears all elements" do
      {:ok, state} = add_element(state_with_scene(), owner: "Alice")
      {:ok, state} = add_element(state, owner: "Bob")

      {:ok, state} = Draw.action(state, [:draw, :clear], %{owner: "GM"})
      assert State.scene(state).drawn_elements == []
    end

    test "non-GM is rejected" do
      assert {:error, "Only GM" <> _} =
               Draw.action(state_with_scene(), [:draw, :clear], %{owner: "Alice"})
    end
  end

  describe "dispatch" do
    test "no active scene returns error" do
      state = %State{active_scene: nil, scenes: %{}}

      assert {:error, "No active scene"} =
               Actions.action(state, [:draw, :add], %{
                 type: :fill,
                 color: "#ff0000",
                 owner: "GM",
                 data: %{}
               })
    end
  end
end
