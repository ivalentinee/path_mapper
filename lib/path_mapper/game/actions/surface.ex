defmodule PathMapper.Game.Actions.Surface do
  @moduledoc """
  Which surface the table is shown, and putting one back to how it arrived.

  There is no action here that changes what a surface *is*. A map arrives as an
  entity and is replaced as an entity, and the surface built on it follows
  through `PathMapper.Game.reconcile/0` — so nothing in this module writes a
  declaration.
  """

  alias PathMapper.Game.State

  def action(%State{active_surface: id} = state, [:surface, :select], id) when is_binary(id) do
    {:ok, state}
  end

  def action(%State{} = state, [:surface, :select], id) when is_binary(id) do
    if Map.has_key?(state.surfaces, id) do
      {:ok, Map.put(state, :active_surface, id)}
    else
      {:error, "No surface #{id} in this session"}
    end
  end

  # A target that is not an id reaches here from anywhere that can be wrong about
  # one. Answering rather than raising matters because this runs inside the Agent:
  # a FunctionClauseError here takes the whole session's state with it.
  def action(%State{} = state, [:surface, :select], _other), do: {:ok, state}

  def action(%State{} = state, [:surface, :unset], _) do
    {:ok, Map.put(state, :active_surface, nil)}
  end

  def action(%State{active_surface: nil} = state, [:surface, :reset], _), do: {:ok, state}

  def action(%State{} = state, [:surface, :reset], _) do
    surface = State.surface(state)
    {:ok, State.put_surface(state, State.Surface.initialize(surface.data))}
  end
end
