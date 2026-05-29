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
