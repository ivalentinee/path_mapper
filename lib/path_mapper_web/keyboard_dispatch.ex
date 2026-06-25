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
    "x" => :eraser
  }

  @measurement_tools Map.values(@measurement_keys)
  @drawing_tools Map.values(@drawing_keys)

  def dispatch(key, assigns, _role \\ :master)

  # 1. Escape — deselect tool or close panel
  def dispatch("Escape", %{scene: %{active_tool: tool}}, _role) when not is_nil(tool) do
    :deselect_tool
  end

  def dispatch("Escape", %{left_panel: %{left_panel: path}}, _role)
      when is_list(path) and path != [] do
    %{left_panel_select: []}
  end

  def dispatch("Escape", _, _role), do: nil

  # 2. Global immediate keys (always active)
  def dispatch("+", _, _), do: :zoom_in
  def dispatch("=", _, _), do: :zoom_in
  def dispatch("-", _, _), do: :zoom_out
  def dispatch("z", %{left_panel: %{left_panel: nil}}, _), do: :zoom_reset
  def dispatch("g", %{left_panel: %{left_panel: nil}}, _), do: :snap_to_grid
  def dispatch("m", %{left_panel: %{left_panel: nil}}, _), do: {:select_tool, :map}
  def dispatch("#", %{left_panel: %{left_panel: nil}}, _), do: :toggle_grid_override

  # Arrow keys — pan viewport by one grid square (when zoomed in)
  def dispatch("ArrowUp", %{scene: %{zoom: zoom}}, _) when zoom > 1.0, do: {:arrow_pan, :up}
  def dispatch("ArrowDown", %{scene: %{zoom: zoom}}, _) when zoom > 1.0, do: {:arrow_pan, :down}
  def dispatch("ArrowLeft", %{scene: %{zoom: zoom}}, _) when zoom > 1.0, do: {:arrow_pan, :left}
  def dispatch("ArrowRight", %{scene: %{zoom: zoom}}, _) when zoom > 1.0, do: {:arrow_pan, :right}

  # 3. Pending prefix resolution (before single-key switching)
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

  # 4. Single-key switching within active tool category (no panel open)
  def dispatch(key, %{left_panel: %{left_panel: nil}, scene: %{active_tool: tool}}, _)
      when tool in @measurement_tools do
    case @measurement_keys[key] do
      nil -> dispatch_prefix(key, nil)
      tool_atom -> {:select_tool, tool_atom}
    end
  end

  def dispatch(key, %{left_panel: %{left_panel: nil}, scene: %{active_tool: tool}}, _)
      when tool in @drawing_tools do
    case @drawing_keys[key] do
      nil -> dispatch_prefix(key, nil)
      tool_atom -> {:select_tool, tool_atom}
    end
  end

  # 5. New prefix initiation (no panel open, no pending prefix)
  def dispatch(key, %{left_panel: %{left_panel: nil}}, _) do
    dispatch_prefix(key, nil)
  end

  # Fallback
  def dispatch(_, _, _), do: nil

  defp dispatch_prefix("q", _), do: {:set_pending_prefix, :q}
  defp dispatch_prefix("d", _), do: {:set_pending_prefix, :d}
  defp dispatch_prefix(_, _), do: nil
end
