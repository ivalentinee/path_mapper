defmodule PathMapperWeb.KeyboardDispatch do
  @moduledoc false

  @measurement_keys %{
    "r" => :ruler,
    "p" => :pointer,
    "b" => :burst,
    "e" => :emanation,
    "c" => :cone,
    "n" => :line
  }

  @drawing_keys %{
    "f" => :fill,
    "r" => :rect,
    "l" => :draw_line,
    "c" => :draw_circle,
    "t" => :text,
    "x" => :eraser,
    "w" => :freeform
  }

  @measurement_tools Map.values(@measurement_keys)
  @drawing_tools Map.values(@drawing_keys)

  @color_keys %{
    "1" => "#8B4513",
    "2" => "#2a2a2a",
    "3" => "#e8e8e8",
    "4" => "#4a7a4a",
    "5" => "#4a6a8a",
    "6" => "#8a3a3a",
    "7" => "#7a7a7a",
    "8" => "#c4a84a"
  }

  @token_action_keys %{
    "x" => "delete",
    "r" => "alive",
    "k" => "dead",
    "u" => "unconscious",
    "v" => "hidden"
  }

  def dispatch(key, assigns, role \\ :master)

  # === 1. Escape (multi-priority) ===

  # 1a. Digit buffer non-empty → clear buffer only (stay in scope)
  def dispatch("Escape", %{scene: %{digit_buffer: buf}}, _) when buf != "" do
    :digit_clear
  end

  # 1b. Tool active, no panel open → deselect tool
  def dispatch("Escape", %{scene: %{active_tool: tool}, left_panel: %{left_panel: nil}}, _)
      when not is_nil(tool) do
    :deselect_tool
  end

  # 1c. Panel open → unwind one level
  def dispatch("Escape", %{left_panel: %{left_panel: path}}, _)
      when is_list(path) and length(path) > 0 do
    parent = List.delete_at(path, -1)

    if length(parent) < 2 do
      :close_all_panels
    else
      %{left_panel_select: parent}
    end
  end

  def dispatch("Escape", _, _), do: nil

  # === 2. Global immediate keys (always active) ===
  def dispatch("+", _, _), do: :zoom_in
  def dispatch("=", _, _), do: :zoom_in
  def dispatch("-", _, _), do: :zoom_out
  def dispatch("z", %{left_panel: %{left_panel: nil}}, _), do: :zoom_reset
  def dispatch("g", %{left_panel: %{left_panel: nil}}, _), do: :snap_to_grid
  def dispatch("m", %{left_panel: %{left_panel: nil}}, _), do: {:select_tool, :map}
  def dispatch("#", %{left_panel: %{left_panel: nil}}, _), do: :toggle_grid_override
  def dispatch("?", %{left_panel: %{left_panel: nil}}, _), do: :toggle_cheatsheet_panel

  # Arrow keys — pan viewport by one grid square (when zoomed in)
  def dispatch("ArrowUp", %{scene: %{zoom: zoom}}, _) when zoom > 1.0, do: {:arrow_pan, :up}
  def dispatch("ArrowDown", %{scene: %{zoom: zoom}}, _) when zoom > 1.0, do: {:arrow_pan, :down}
  def dispatch("ArrowLeft", %{scene: %{zoom: zoom}}, _) when zoom > 1.0, do: {:arrow_pan, :left}
  def dispatch("ArrowRight", %{scene: %{zoom: zoom}}, _) when zoom > 1.0, do: {:arrow_pan, :right}

  # === 3. Enter — commit digit buffer ===
  def dispatch("Enter", %{scene: %{digit_buffer: buf}, left_panel: %{left_panel: path}}, _)
      when buf != "" do
    case Integer.parse(buf) do
      {index, ""} -> commit_for_scope(path, index)
      _ -> :digit_clear
    end
  end

  # === 4. Digit accumulation (when panel scope is open) ===
  def dispatch(key, %{left_panel: %{left_panel: path}}, _)
      when key in ~w(0 1 2 3 4 5 6 7 8 9) and is_list(path) and length(path) > 0 do
    {:digit_append, key}
  end

  # === 5. Scope-specific action keys (when panel is open) ===

  # Scene scope
  def dispatch("u", %{left_panel: %{left_panel: ["left-panel", "scene-selector"]}}, _) do
    {:scene_action, :unset}
  end

  def dispatch("r", %{left_panel: %{left_panel: ["left-panel", "scene-selector"]}}, _) do
    {:scene_action, :reset}
  end

  # Tokens scope — sub-panel navigation
  def dispatch("a", %{left_panel: %{left_panel: ["left-panel", "tokens"]}}, _) do
    %{left_panel_select: ["left-panel", "tokens", "add-token"]}
  end

  def dispatch("p", %{left_panel: %{left_panel: ["left-panel", "tokens"]}}, _) do
    %{left_panel_select: ["left-panel", "tokens", "add-player-token"]}
  end

  def dispatch("e", %{left_panel: %{left_panel: ["left-panel", "tokens"]}}, _) do
    %{left_panel_select: ["left-panel", "tokens", "add-extra-token"]}
  end

  def dispatch("h", %{left_panel: %{left_panel: ["left-panel", "tokens"]}}, _) do
    %{left_panel_select: ["left-panel", "tokens", "add-adhoc-token"]}
  end

  # Token action sub-scope (after selecting a token by index)
  def dispatch(key, %{left_panel: %{left_panel: ["left-panel", "tokens", idx]}}, _)
      when is_integer(idx) do
    case @token_action_keys[key] do
      nil -> nil
      action -> {:token_action, idx, action}
    end
  end

  # Players sub-scope — add all
  def dispatch("a", %{left_panel: %{left_panel: ["left-panel", "tokens", "add-player-token"]}}, _) do
    {:player_action, :add_all}
  end

  # Layers scope
  def dispatch("g", %{left_panel: %{left_panel: ["left-panel", "map-manager"]}}, _) do
    {:map_action, :toggle_grid}
  end

  # Layer sub-scope actions
  def dispatch("s", %{left_panel: %{left_panel: ["left-panel", "map-manager", idx]}}, _)
      when is_integer(idx) do
    {:layer_action, idx, :toggle_show}
  end

  def dispatch("i", %{left_panel: %{left_panel: ["left-panel", "map-manager", idx]}}, _)
      when is_integer(idx) do
    {:layer_action, idx, :toggle_light}
  end

  def dispatch("h", %{left_panel: %{left_panel: ["left-panel", "map-manager", idx]}}, _)
      when is_integer(idx) do
    {:layer_action, idx, :toggle_highlight}
  end

  # === 6. Pending prefix resolution ===
  def dispatch(key, %{left_panel: %{left_panel: nil}, scene: %{pending_prefix: :q}}, _) do
    case @measurement_keys[key] do
      nil -> {:set_pending_prefix, nil}
      tool -> {:select_tool, tool}
    end
  end

  def dispatch(key, %{left_panel: %{left_panel: nil}, scene: %{pending_prefix: :d}}, _) do
    case @drawing_keys[key] do
      nil -> {:set_pending_prefix, nil}
      tool -> {:select_tool, tool}
    end
  end

  # 6c. Pending prefix :c → color selection
  def dispatch(key, %{left_panel: %{left_panel: nil}, scene: %{pending_prefix: :c}}, _) do
    case @color_keys[key] do
      nil -> {:set_pending_prefix, nil}
      color -> {:set_draw_color, color}
    end
  end

  # 6d. Color prefix entry: c when drawing tool active
  def dispatch("c", %{left_panel: %{left_panel: nil}, scene: %{active_tool: tool}}, _)
      when tool in @drawing_tools do
    {:set_pending_prefix, :c}
  end

  # === 7. Single-key switching within active tool category ===
  def dispatch(key, %{left_panel: %{left_panel: nil}, scene: %{active_tool: tool}}, _)
      when tool in @measurement_tools do
    case @measurement_keys[key] do
      nil -> dispatch_global(key, nil)
      tool_atom -> {:select_tool, tool_atom}
    end
  end

  def dispatch(key, %{left_panel: %{left_panel: nil}, scene: %{active_tool: tool}}, _)
      when tool in @drawing_tools do
    case @drawing_keys[key] do
      nil -> dispatch_global(key, nil)
      tool_atom -> {:select_tool, tool_atom}
    end
  end

  # === 8. Global scope — prefixes and panel scope keys ===
  def dispatch(key, %{left_panel: %{left_panel: nil}} = assigns, _) do
    dispatch_global(key, assigns)
  end

  # === 9. Fallback (panel open, unrecognized key) ===
  def dispatch(_, _, _), do: nil

  # --- Private helpers ---

  defp dispatch_global("q", _), do: {:set_pending_prefix, :q}
  defp dispatch_global("d", _), do: {:set_pending_prefix, :d}

  defp dispatch_global("s", %{game_state: gs}) when gs != nil do
    %{left_panel_select: ["left-panel", "scene-selector"]}
  end

  defp dispatch_global("t", %{game_state: %{scene: scene}}) when scene != nil do
    %{left_panel_select: ["left-panel", "tokens"]}
  end

  defp dispatch_global("l", %{game_state: %{scene: %{custom: false}}}) do
    %{left_panel_select: ["left-panel", "map-manager"]}
  end

  defp dispatch_global("i", %{game_state: gs}) when gs != nil do
    %{left_panel_select: ["left-panel", "initiative"]}
  end

  defp dispatch_global("u", _), do: :draw_undo

  defp dispatch_global(_, _), do: nil

  # Digit commit: map scope path to action
  defp commit_for_scope(["left-panel", "scene-selector"], index) do
    {:scene_select, index}
  end

  defp commit_for_scope(["left-panel", "tokens"], index) do
    {:token_select, index}
  end

  defp commit_for_scope(["left-panel", "tokens", "add-token"], index) do
    {:add_token_by_index, index}
  end

  defp commit_for_scope(["left-panel", "tokens", "add-player-token"], index) do
    {:add_player_by_index, index}
  end

  defp commit_for_scope(["left-panel", "map-manager"], index) do
    {:layer_select, index}
  end

  defp commit_for_scope(["left-panel", "tokens", "add-extra-token"], index) do
    {:extra_select_player, index}
  end

  defp commit_for_scope(["left-panel", "tokens", "add-extra-token", player_idx, "add"], index) do
    {:add_extra_by_index, player_idx, index}
  end

  defp commit_for_scope(_, _), do: :digit_clear
end
