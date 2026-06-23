defmodule PathMapper.Game.Actions do
  alias PathMapper.Game.State

  def action(%State{} = state, [:scene | _rest] = action, data),
    do: __MODULE__.Scene.action(state, action, data)

  def action(%State{} = state, [:initiative | _rest] = action, data),
    do: __MODULE__.Initiative.action(state, action, data)

  def action(%State{active_scene: nil}, [:map | _], _data),
    do: {:error, "No active scene"}

  def action(%State{active_scene: nil}, [:tokens | _], _data),
    do: {:error, "No active scene"}

  def action(%State{active_scene: nil}, [:map_objects | _], _data),
    do: {:error, "No active scene"}

  def action(%State{} = state, [:map | _rest] = action, data),
    do: __MODULE__.Map.action(state, action, data)

  def action(%State{} = state, [:tokens | _rest] = action, data),
    do: __MODULE__.Tokens.action(state, action, data)

  def action(%State{} = state, [:map_objects | _rest] = action, data),
    do: __MODULE__.MapObjects.action(state, action, data)

  def action(%State{active_scene: nil}, [:draw | _], _data),
    do: {:error, "No active scene"}

  def action(%State{} = state, [:draw | _rest] = action, data),
    do: __MODULE__.Draw.action(state, action, data)

  def action(%State{} = _state, action, _data) do
    {:error, "Action '#{inspect(action)}' not found"}
  end
end
