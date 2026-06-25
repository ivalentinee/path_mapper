defmodule PathMapperWeb.KeyboardDispatchTest do
  use ExUnit.Case, async: true

  alias PathMapperWeb.KeyboardDispatch
  alias PathMapperWeb.MasterLive.LeftPanelState
  alias PathMapperWeb.Scene.SceneState

  defp assigns(overrides \\ %{}) do
    base = %{
      scene: %SceneState{},
      left_panel: %LeftPanelState{}
    }

    Map.merge(base, overrides)
  end

  describe "global keys" do
    test "Escape deselects tool when tool active" do
      assert :deselect_tool =
               KeyboardDispatch.dispatch(
                 "Escape",
                 assigns(%{scene: %SceneState{active_tool: :ruler}})
               )
    end

    test "Escape closes panel when panel open" do
      assert %{left_panel_select: []} =
               KeyboardDispatch.dispatch(
                 "Escape",
                 assigns(%{left_panel: %LeftPanelState{left_panel: ["left-panel", "tokens"]}})
               )
    end

    test "Escape is no-op when nothing active" do
      assert nil == KeyboardDispatch.dispatch("Escape", assigns())
    end

    test "+ zooms in" do
      assert :zoom_in == KeyboardDispatch.dispatch("+", assigns())
    end

    test "= also zooms in" do
      assert :zoom_in == KeyboardDispatch.dispatch("=", assigns())
    end

    test "- zooms out" do
      assert :zoom_out == KeyboardDispatch.dispatch("-", assigns())
    end

    test "z resets zoom" do
      assert :zoom_reset == KeyboardDispatch.dispatch("z", assigns())
    end

    test "g toggles snap-to-grid" do
      assert :snap_to_grid == KeyboardDispatch.dispatch("g", assigns())
    end

    test "m selects map tool" do
      assert {:select_tool, :map} == KeyboardDispatch.dispatch("m", assigns())
    end

    test "# toggles grid override" do
      assert :toggle_grid_override == KeyboardDispatch.dispatch("#", assigns())
    end

    test "unrecognized key returns nil" do
      assert nil == KeyboardDispatch.dispatch("x", assigns())
    end
  end

  describe "arrow keys" do
    test "arrow up pans when zoomed in" do
      assert {:arrow_pan, :up} =
               KeyboardDispatch.dispatch("ArrowUp", assigns(%{scene: %SceneState{zoom: 2.0}}))
    end

    test "arrow keys ignored at zoom 1.0" do
      assert nil ==
               KeyboardDispatch.dispatch("ArrowUp", assigns(%{scene: %SceneState{zoom: 1.0}}))
    end
  end

  describe "tool prefixes" do
    test "q sets pending prefix" do
      assert {:set_pending_prefix, :q} == KeyboardDispatch.dispatch("q", assigns())
    end

    test "d sets pending prefix" do
      assert {:set_pending_prefix, :d} == KeyboardDispatch.dispatch("d", assigns())
    end

    test "q then r selects ruler" do
      assert {:select_tool, :ruler} =
               KeyboardDispatch.dispatch("r", assigns(%{scene: %SceneState{pending_prefix: :q}}))
    end

    test "d then f selects fill" do
      assert {:select_tool, :fill} =
               KeyboardDispatch.dispatch("f", assigns(%{scene: %SceneState{pending_prefix: :d}}))
    end

    test "d then invalid key clears prefix" do
      # Use a truly unrecognized key (not a global key like z)
      assert {:set_pending_prefix, nil} =
               KeyboardDispatch.dispatch("w", assigns(%{scene: %SceneState{pending_prefix: :d}}))
    end
  end

  describe "single-key switching" do
    test "b switches to burst when ruler active" do
      assert {:select_tool, :burst} =
               KeyboardDispatch.dispatch("b", assigns(%{scene: %SceneState{active_tool: :ruler}}))
    end

    test "f switches to fill when rect active" do
      assert {:select_tool, :fill} =
               KeyboardDispatch.dispatch("f", assigns(%{scene: %SceneState{active_tool: :rect}}))
    end

    test "switching suppressed when panel open" do
      assert nil ==
               KeyboardDispatch.dispatch(
                 "b",
                 assigns(%{
                   scene: %SceneState{active_tool: :ruler},
                   left_panel: %LeftPanelState{left_panel: ["left-panel", "tokens"]}
                 })
               )
    end
  end

  describe "keys suppressed when panel open" do
    test "z ignored when panel open" do
      assert nil ==
               KeyboardDispatch.dispatch(
                 "z",
                 assigns(%{left_panel: %LeftPanelState{left_panel: ["left-panel", "tokens"]}})
               )
    end

    test "m ignored when panel open" do
      assert nil ==
               KeyboardDispatch.dispatch(
                 "m",
                 assigns(%{left_panel: %LeftPanelState{left_panel: ["left-panel", "tokens"]}})
               )
    end
  end
end
