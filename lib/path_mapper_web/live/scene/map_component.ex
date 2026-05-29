defmodule PathMapperWeb.Scene.MapComponent do
  use PathMapperWeb, :live_component

  alias PathMapper.Adventures.Adventure
  alias PathMapper.Game.State.Scene.Map.Layer
  alias PathMapper.Geometry.Mapper, as: GeometryMapper

  def layer_image_class(%Layer{highlight: true}, _opts), do: "highlight"
  def layer_image_class(%Layer{show: false}, %{show_hidden: true}), do: "darken"
  def layer_image_class(%Layer{show: false}, _opts), do: "hide"
  def layer_image_class(%Layer{light: "dim"}, _opts), do: "dimmed"
  def layer_image_class(%Layer{}, _opts), do: ""

  def selected_layer_class(selected_layer_index, layer_index)
      when selected_layer_index == layer_index,
      do: "selected"

  def selected_layer_class(_selected_layer_index, _layer_index), do: ""

  def additional_map_layer(adventure, game_state, name, override \\ false)

  def additional_map_layer(_adventure, %{scene: %{map: %{show_grid: false}}}, :grid, false),
    do: nil

  def additional_map_layer(adventure, game_state, name, _override) when is_atom(name) do
    adventure
    |> Adventure.get_scene_map(game_state.scene.index)
    |> Map.get(name)
  end

  def map_adventure_layers_to_state(adventure, game_state) do
    state_layers = game_state.scene.map.layers

    adventure
    |> Adventure.get_scene_map(game_state.scene.index)
    |> Map.get(:layers)
    |> Enum.map(fn layer ->
      state = Enum.find(state_layers, &(&1.index == layer.index))
      {layer, state}
    end)
    |> Enum.reject(fn {_, state} -> is_nil(state) end)
  end

  def layer_images(layer) do
    case layer do
      %{images: images} when is_list(images) and images != [] ->
        Enum.reverse(images)

      %{image: image} when not is_nil(image) ->
        [%{image: image, x: layer.x, y: layer.y, width: layer.width, height: layer.height}]

      _ ->
        []
    end
  end
end
