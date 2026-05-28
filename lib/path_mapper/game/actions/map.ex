defmodule PathMapper.Game.Actions.Map do
  alias PathMapper.Game.State
  alias PathMapper.Game.State.Scene.Map.Layer

  def action(%State{} = state, [:map, :toggle_grid], _) do
    scene = State.scene(state)
    updated_map = Map.put(scene.map, :show_grid, !scene.map.show_grid)
    updated_scene = Map.put(scene, :map, updated_map)
    {:ok, State.put_scene(state, updated_scene)}
  end

  def action(%State{} = state, [:map, :layer, :toggle_show], index) when is_number(index) do
    layer = Enum.at(State.scene(state).map.layers, index)

    if layer do
      updated_layer = Map.put(layer, :show, !layer.show)
      {:ok, update_layer(state, updated_layer, index)}
    else
      {:ok, state}
    end
  end

  def action(%State{} = state, [:map, :layer, :toggle_light], index) when is_number(index) do
    layer = Enum.at(State.scene(state).map.layers, index)

    if layer do
      light = if layer.light == "bright", do: "dim", else: "bright"
      updated_layer = Map.put(layer, :light, light)
      {:ok, update_layer(state, updated_layer, index)}
    else
      {:ok, state}
    end
  end

  def action(%State{} = state, [:map, :layer, :toggle_highlight], index) when is_number(index) do
    layer = Enum.at(State.scene(state).map.layers, index)

    if layer do
      updated_layer = Map.put(layer, :highlight, !layer.highlight)
      {:ok, update_layer(state, updated_layer, index)}
    else
      {:ok, state}
    end
  end

  def action(%State{} = _state, action, _data) do
    {:error, "Map action '#{inspect(action)}' not found"}
  end

  defp update_layer(%State{} = state, %Layer{} = new_layer_state, layer_index) do
    scene = State.scene(state)
    updated_layers = List.replace_at(scene.map.layers, layer_index, new_layer_state)
    updated_map = Map.put(scene.map, :layers, updated_layers)
    State.put_scene(state, Map.put(scene, :map, updated_map))
  end
end
