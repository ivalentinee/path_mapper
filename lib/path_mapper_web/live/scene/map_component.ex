defmodule PathMapperWeb.Scene.MapComponent do
  use PathMapperWeb, :live_component

  alias PathMapper.Adventures.Adventure
  alias PathMapper.Game.State.Scene.Map.Layer

  def layer_image_class(%Layer{highlight: true}, _opts), do: "highlight"
  def layer_image_class(%Layer{show: false}, %{show_hidden: true}), do: "darken"
  def layer_image_class(%Layer{show: false}, _opts), do: "hide"
  def layer_image_class(%Layer{light: "dim"}, _opts), do: "dimmed"
  def layer_image_class(%Layer{}, _opts), do: ""

  def selected_layer_class(selected_layer_index, layer_index)
      when selected_layer_index == layer_index,
      do: "selected"

  def selected_layer_class(_selected_layer_index, _layer_index), do: ""

  def additional_map_layer(_adventure, %{scene: %{map: %{show_grid: false}}}, :grid), do: nil

  def additional_map_layer(adventure, game_state, name) when is_atom(name) do
    adventure
    |> Adventure.get_scene_map(game_state.scene.index)
    |> Map.get(name)
  end

  def map_adventure_layers_to_state(adventure, game_state) do
    adventure
    |> Adventure.get_scene_map(game_state.scene.index)
    |> Map.get(:layers)
    |> Enum.with_index()
    |> Enum.map(fn {layer, index} -> {layer, Enum.at(game_state.scene.map.layers, index)} end)
  end
end
