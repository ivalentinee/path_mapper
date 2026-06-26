defmodule PathMapperWeb.Scene.RightPanelComponent do
  use PathMapperWeb, :live_component

  alias PathMapper.Game
  alias PathMapper.Game.Palette

  embed_templates "right_panel/*"

  @impl true
  def handle_event("toggle_group_panel", _, socket) do
    send(self(), %{session_event: :toggle_group_panel})
    {:noreply, socket}
  end

  @impl true
  def handle_event("toggle_character_panel", _, socket) do
    send(self(), %{session_event: :toggle_character_panel})
    {:noreply, socket}
  end

  @impl true
  def handle_event("toggle_links_panel", _, socket) do
    send(self(), %{session_event: :toggle_links_panel})
    {:noreply, socket}
  end

  @impl true
  def handle_event("claim_character", %{"name" => name}, socket) do
    if socket.assigns[:is_player] do
      send(self(), %{session_event: {:claim_character, name}})
    end

    {:noreply, socket}
  end

  @impl true
  def handle_event("add_player_token", %{"name" => name}, socket) do
    Game.run_action([:tokens, :player, :add], name)
    {:noreply, socket}
  end

  @impl true
  def handle_event("remove_player_token", %{"name" => name}, socket) do
    case find_token_index_by_name(name) do
      nil -> :ok
      index -> Game.run_action([:tokens, :delete], index)
    end

    {:noreply, socket}
  end

  @impl true
  def handle_event("add_extra_token", %{"name" => name, "index" => index_str}, socket) do
    case Integer.parse(index_str) do
      {index, _} -> Game.run_action([:tokens, :player, :add_extra], {name, index})
      _ -> :ok
    end

    {:noreply, socket}
  end

  @impl true
  def handle_event("select_tool", %{"tool" => tool}, socket) do
    send(self(), %{session_event: {:select_tool, String.to_existing_atom(tool)}})
    {:noreply, socket}
  end

  @impl true
  def handle_event("deselect_tool", _, socket) do
    send(self(), %{session_event: :deselect_tool})
    {:noreply, socket}
  end

  @impl true
  def handle_event("toggle_grid_override", _, socket) do
    send(self(), %{session_event: :toggle_grid_override})
    {:noreply, socket}
  end

  @impl true
  def handle_event("snap_to_grid", _, socket) do
    send(self(), %{session_event: :snap_to_grid})
    {:noreply, socket}
  end

  @impl true
  def handle_event("set_draw_width", %{"value" => value_str}, socket) do
    case Integer.parse(value_str) do
      {width, _} when width >= 1 and width <= 20 ->
        send(self(), %{session_event: {:set_draw_width, width}})

      _ ->
        :ok
    end

    {:noreply, socket}
  end

  @impl true
  def handle_event("set_draw_color", %{"color" => color}, socket) do
    send(self(), %{session_event: {:set_draw_color, color}})
    {:noreply, socket}
  end

  @impl true
  def handle_event("toggle_cheatsheet_panel", _, socket) do
    send(self(), %{session_event: :toggle_cheatsheet_panel})
    {:noreply, socket}
  end

  @impl true
  def handle_event("zoom_in", _, socket) do
    send(self(), %{session_event: :zoom_in})
    {:noreply, socket}
  end

  @impl true
  def handle_event("zoom_out", _, socket) do
    send(self(), %{session_event: :zoom_out})
    {:noreply, socket}
  end

  @impl true
  def handle_event("zoom_reset", _, socket) do
    send(self(), %{session_event: :zoom_reset})
    {:noreply, socket}
  end

  @impl true
  def handle_event("set_locale", %{"locale" => locale}, socket) do
    {:noreply, push_event(socket, "set_locale", %{locale: locale})}
  end

  @impl true
  def handle_event("toggle_initiative_panel", _, socket) do
    send(self(), %{session_event: :toggle_initiative_panel})
    {:noreply, socket}
  end

  @impl true
  def handle_event("submit_initiative", %{"value" => value_str}, socket) do
    with {value, _} <- Integer.parse(value_str),
         %{character_name: name} <- socket.assigns[:my_player] do
      Game.run_action([:initiative, :add], %{name: name, value: value, owner: name})
    end

    {:noreply, socket}
  end

  @impl true
  def handle_event("noop", _, socket), do: {:noreply, socket}

  defp charkeeper_status_title(:ok), do: gettext("Charkeeper: connected")
  defp charkeeper_status_title(:partial), do: gettext("Charkeeper: partial")
  defp charkeeper_status_title(:error), do: gettext("Charkeeper: error")
  defp charkeeper_status_title(_), do: nil

  defp charkeeper_for(charkeeper_data, player) do
    Map.get(charkeeper_data || %{}, player.character_name)
  end

  defp hp_bar_percent(_hp_current, _hp_temp, hp_max) when hp_max <= 0, do: {0, 0}

  defp hp_bar_percent(hp_current, hp_temp, hp_max) do
    current = Kernel.max(hp_current, 0)
    effective_max = Kernel.max(hp_max, current + hp_temp)
    {current / effective_max * 100, hp_temp / effective_max * 100}
  end

  defp hp_color_class(_hp_current, hp_max) when hp_max <= 0, do: "critical"

  defp hp_color_class(hp_current, hp_max) do
    ratio = Kernel.max(hp_current, 0) / hp_max

    cond do
      ratio >= 0.5 -> "healthy"
      ratio >= 0.25 -> "wounded"
      true -> "critical"
    end
  end

  defp tool_label(:ruler), do: gettext("Ruler")
  defp tool_label(:pointer), do: gettext("Pointer")
  defp tool_label(:burst), do: gettext("Burst")
  defp tool_label(:emanation), do: gettext("Emanation")
  defp tool_label(:cone), do: gettext("Cone")
  defp tool_label(:line), do: gettext("Line")
  defp tool_label(:map), do: gettext("Map")
  defp tool_label(:fill), do: gettext("Fill")
  defp tool_label(:rect), do: gettext("Rect")
  defp tool_label(:draw_line), do: gettext("Draw line")
  defp tool_label(:draw_circle), do: gettext("Draw circle")
  defp tool_label(:freeform), do: gettext("Freeform")
  defp tool_label(:eraser), do: gettext("Eraser")
  defp tool_label(:text), do: gettext("Text")

  @draw_colors [
    {"#8B4513", "Brown"},
    {"#2a2a2a", "Black"},
    {"#e8e8e8", "White"},
    {"#4a7a4a", "Green"},
    {"#4a6a8a", "Blue"},
    {"#8a3a3a", "Red"},
    {"#7a7a7a", "Gray"},
    {"#c4a84a", "Sand"}
  ]

  @drawing_tools [:fill, :rect, :draw_line, :draw_circle, :freeform, :text, :eraser]

  defp draw_colors, do: @draw_colors
  defp drawing_tool?(tool), do: tool in @drawing_tools
  defp width_tool?(tool), do: tool in [:freeform, :rect, :draw_line, :draw_circle]

  defp format_zoom(zoom) do
    :erlang.float_to_binary(zoom + 0.0, decimals: 2)
    |> String.trim_trailing("0")
    |> String.trim_trailing(".")
    |> Kernel.<>("x")
  end

  defp my_initiative_value(initiative, character_name) do
    case Enum.find(initiative, &(&1.owner == character_name)) do
      %{value: value} -> value
      _ -> nil
    end
  end

  defp initiative_color(nil), do: "#808080"
  defp initiative_color(owner), do: Palette.resolve(owner)

  defp find_token_index_by_name(name) do
    tokens = scene_tokens()

    Enum.find_value(Enum.with_index(tokens), fn {token, index} ->
      if token.data.name == name, do: index
    end)
  end

  defp scene_tokens do
    case Game.get_state() do
      %{scene: %{tokens: tokens}} when is_list(tokens) -> tokens
      _ -> []
    end
  end
end
