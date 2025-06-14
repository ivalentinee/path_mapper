defmodule PathMapper.Game.Actions.Map do
  alias PathMapper.Game.State
  alias PathMapper.Game.State.Scene.Map.Layer

  def action(%State{} = state, [:map, :layer, :toggle_show], index) when is_number(index) do
    layer = Enum.at(state.scene.map.layers, index)

    if layer do
      updated_layer = Map.put(layer, :show, !layer.show)
      {:ok, update_layer(state, updated_layer, index)}
    else
      {:ok, state}
    end
  end

  def action(%State{} = state, [:map, :layer, :toggle_light], index) when is_number(index) do
    layer = Enum.at(state.scene.map.layers, index)

    if layer do
      light = if layer.light == "bright", do: "dim", else: "bright"
      updated_layer = Map.put(layer, :light, light)
      {:ok, update_layer(state, updated_layer, index)}
    else
      {:ok, state}
    end
  end

  def action(%State{} = state, [:map, :layer, :toggle_highlight], index) when is_number(index) do
    layer = Enum.at(state.scene.map.layers, index)

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

  defp update_layer(%State{} = state, %Layer{} = new_layer_state, index) do
    updated_layers = List.replace_at(state.scene.map.layers, index, new_layer_state)
    updated_map = Map.put(state.scene.map, :layers, updated_layers)
    updated_scene = Map.put(state.scene, :map, updated_map)
    Map.put(state, :scene, updated_scene)
  end
end
