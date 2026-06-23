defmodule PathMapper.Game.Actions.MapObjects do
  alias PathMapper.Game.State
  alias PathMapper.Game.State.Scene.Map.MapObject
  alias PathMapper.Geometry.Mapper, as: GeometryMapper

  def action(%State{} = state, [:map_objects, index, :drag], {x, y})
      when is_integer(index) and is_number(x) and is_number(y) do
    case get_object(state, index) do
      %MapObject{locked: true} -> {:ok, state}
      %MapObject{} = obj -> update_object(state, index, Map.merge(obj, %{drag_x: x, drag_y: y}))
      nil -> {:ok, state}
    end
  end

  def action(%State{} = state, [:map_objects, index, :move], {x, y})
      when is_integer(index) and is_number(x) and is_number(y) do
    case get_object(state, index) do
      %MapObject{locked: true} ->
        {:ok, state}

      %MapObject{} = obj ->
        update_object(state, index, Map.merge(obj, %{x: x, y: y, drag_x: nil, drag_y: nil}))

      nil ->
        {:ok, state}
    end
  end

  def action(%State{} = state, [:map_objects, index, :toggle_lock], _)
      when is_integer(index) do
    case get_object(state, index) do
      %MapObject{} = obj -> update_object(state, index, Map.put(obj, :locked, !obj.locked))
      nil -> {:ok, state}
    end
  end

  def action(%State{} = state, [:map_objects, index, :toggle_show], _)
      when is_integer(index) do
    case get_object(state, index) do
      %MapObject{} = obj -> update_object(state, index, Map.put(obj, :show, !obj.show))
      nil -> {:ok, state}
    end
  end

  def action(%State{} = state, [:map_objects, index, :reset_position], _)
      when is_integer(index) do
    scene = State.scene(state)

    adventure_obj =
      if scene.data, do: Enum.at(scene.data.map.map_objects, index), else: nil

    if adventure_obj do
      reset = %MapObject{
        index: index,
        layer_index: adventure_obj.layer_index,
        x: GeometryMapper.to_subpixels(adventure_obj.x),
        y: GeometryMapper.to_subpixels(adventure_obj.y),
        locked: true,
        show: true
      }

      update_object(state, index, reset)
    else
      {:ok, state}
    end
  end

  def action(%State{} = _state, action, _data) do
    {:error, "Map objects action '#{inspect(action)}' not found"}
  end

  defp get_object(state, index) do
    Enum.at(State.scene(state).map.map_objects, index)
  end

  defp update_object(state, index, updated_object) do
    scene = State.scene(state)
    updated_objects = List.replace_at(scene.map.map_objects, index, updated_object)
    updated_map = Map.put(scene.map, :map_objects, updated_objects)
    updated_scene = Map.put(scene, :map, updated_map)
    {:ok, State.put_scene(state, updated_scene)}
  end
end
