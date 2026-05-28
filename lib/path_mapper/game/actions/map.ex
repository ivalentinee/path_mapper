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
    if layer = find_layer(state, index) do
      {:ok, update_layer(state, index, Map.put(layer, :show, !layer.show))}
    else
      {:ok, state}
    end
  end

  def action(%State{} = state, [:map, :layer, :toggle_light], index) when is_number(index) do
    if layer = find_layer(state, index) do
      light = if layer.light == "bright", do: "dim", else: "bright"
      {:ok, update_layer(state, index, Map.put(layer, :light, light))}
    else
      {:ok, state}
    end
  end

  def action(%State{} = state, [:map, :layer, :toggle_highlight], index) when is_number(index) do
    if layer = find_layer(state, index) do
      {:ok, update_layer(state, index, Map.put(layer, :highlight, !layer.highlight))}
    else
      {:ok, state}
    end
  end

  def action(%State{} = _state, action, _data) do
    {:error, "Map action '#{inspect(action)}' not found"}
  end

  defp find_layer(state, index) do
    Enum.find(State.scene(state).map.layers, &(&1.index == index))
  end

  defp update_layer(%State{} = state, index, %Layer{} = updated_layer) do
    scene = State.scene(state)

    updated_layers =
      Enum.map(scene.map.layers, fn layer ->
        if layer.index == index, do: updated_layer, else: layer
      end)

    updated_map = Map.put(scene.map, :layers, updated_layers)
    State.put_scene(state, Map.put(scene, :map, updated_map))
  end
end
