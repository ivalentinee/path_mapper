defmodule PathMapper.Game.Actions.Scene do
  alias PathMapper.Game.Initialize
  alias PathMapper.Game.State

  def action(%State{active_scene: index} = state, [:scene, :select], index)
      when is_integer(index) do
    {:ok, state}
  end

  def action(%State{} = state, [:scene, :select], index) when is_integer(index) do
    if Map.has_key?(state.scenes, index) do
      {:ok, Map.put(state, :active_scene, index)}
    else
      {:error, "Scene #{index} not found in initialized scenes"}
    end
  end

  def action(%State{} = state, [:scene, :unset], _) do
    {:ok, Map.put(state, :active_scene, nil)}
  end

  def action(%State{active_scene: nil} = state, [:scene, :reset], _), do: {:ok, state}

  def action(%State{} = state, [:scene, :reset], _) do
    scene = State.scene(state)

    if scene.custom do
      {:error, "Cannot reset custom scenes"}
    else
      new_scene = Initialize.build_scene(scene.data, state.active_scene)
      {:ok, State.put_scene(state, new_scene)}
    end
  end

  def action(%State{} = state, [:scene, :create], %{"name" => name})
      when is_binary(name) do
    trimmed = name |> String.trim() |> String.slice(0, 50)

    cond do
      trimmed == "" ->
        {:error, "Scene name cannot be empty"}

      scene_name_taken?(state, trimmed) ->
        {:error, "Scene name already exists"}

      true ->
        index = next_scene_index(state)
        scene = State.Scene.initialize_custom(trimmed, index)
        new_scenes = Map.put(state.scenes, index, scene)
        {:ok, %{state | scenes: new_scenes, active_scene: index}}
    end
  end

  def action(%State{} = state, [:scene, :delete], index) when is_integer(index) do
    case Map.get(state.scenes, index) do
      %State.Scene{custom: true} ->
        new_scenes = Map.delete(state.scenes, index)
        active = if state.active_scene == index, do: nil, else: state.active_scene
        {:ok, %{state | scenes: new_scenes, active_scene: active}}

      %State.Scene{custom: false} ->
        {:error, "Cannot delete adventure scenes"}

      nil ->
        {:error, "Scene not found"}
    end
  end

  defp next_scene_index(%State{scenes: scenes}) do
    case Map.keys(scenes) do
      [] -> 0
      keys -> Enum.max(keys) + 1
    end
  end

  defp scene_name_taken?(%State{scenes: scenes}, name) do
    Enum.any?(scenes, fn {_idx, scene} -> scene.name == name end)
  end
end
