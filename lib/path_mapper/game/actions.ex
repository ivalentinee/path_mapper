defmodule PathMapper.Game.Actions do
  alias PathMapper.Adventures
  alias PathMapper.Game.State
  alias PathMapper.Groups

  def action(%State{} = state, :select_scene, index) when is_number(index) do
    with {:ok, adventure} <- Adventures.get_loaded(),
         {:ok, _group} <- Groups.get_loaded(),
         {:ok, adventure_scene} <- Adventures.Adventure.get_scene(adventure, index) do
      new_state = Map.put(state, :scene, State.Scene.initialize(adventure_scene, index))
      {:ok, new_state}
    else
      _error -> {:ok, state}
    end
  end

  def action(%State{} = state, [:map | _rest] = action, data),
    do: __MODULE__.Map.action(state, action, data)

  def action(%State{} = state, [:tokens | _rest] = action, data),
    do: __MODULE__.Tokens.action(state, action, data)

  def action(%State{} = _state, action, _data) do
    {:error, "Action '#{inspect(action)}' not found"}
  end
end
