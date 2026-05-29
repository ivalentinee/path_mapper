defmodule PathMapper.Game.Actions.Initiative do
  alias PathMapper.Game.State

  @non_player_owners [nil, "enemy", "npc", "none"]

  def action(%State{} = state, [:initiative, :add], %{name: name, value: value} = params)
      when is_binary(name) and is_integer(value) do
    # Player owners get upserted (remove existing before insert).
    # Non-player owners ("enemy", "npc") can have multiple entries.
    cleaned =
      case params[:owner] do
        owner when owner in @non_player_owners -> state.initiative
        owner -> Enum.reject(state.initiative, &(&1.owner == owner))
      end

    entry = %{
      id: to_string(System.unique_integer([:positive])),
      name: name,
      value: value,
      owner: params[:owner]
    }

    {:ok, %{state | initiative: insert_sorted(cleaned, entry)}}
  end

  def action(%State{} = state, [:initiative, :remove], id) when is_binary(id) do
    {:ok, %{state | initiative: Enum.reject(state.initiative, &(&1.id == id))}}
  end

  def action(%State{} = state, [:initiative, :reset], _) do
    {:ok, %{state | initiative: []}}
  end

  defp insert_sorted(list, entry) do
    {before, after_} = Enum.split_while(list, &(&1.value >= entry.value))
    before ++ [entry] ++ after_
  end
end
