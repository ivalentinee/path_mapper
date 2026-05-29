defmodule PathMapper.Game do
  defstruct [:state]

  use Agent

  alias __MODULE__.Actions
  alias __MODULE__.Initialize
  alias __MODULE__.Palette
  alias __MODULE__.State
  alias PathMapper.Adventures
  alias PathMapper.Adventures.Adventure
  alias PathMapper.Groups
  alias Phoenix.PubSub

  @update_pubsub_topic "game"

  def subscribe do
    PubSub.subscribe(PathMapper.PubSub, @update_pubsub_topic)
  end

  def broadcast(event) do
    PubSub.broadcast(PathMapper.PubSub, @update_pubsub_topic, event)
  end

  def start_link(_) do
    Agent.start_link(fn -> nil end, name: __MODULE__)
  end

  def get_state do
    Agent.get(__MODULE__, fn
      %__MODULE__{state: %State{} = state} -> %{scene: State.scene(state)}
      _ -> nil
    end)
  end

  def load(adventure_filename) when is_binary(adventure_filename) do
    with {:ok, adventure} <- Adventures.load_adventure(adventure_filename) do
      reset(adventure)
      rebuild_palette()
      {:ok, adventure}
    end
  end

  defp rebuild_palette do
    group =
      case Groups.get_loaded() do
        {:ok, group} -> group
        _ -> nil
      end

    Palette.build(group) |> Palette.store()
  end

  def reset(%Adventure{} = adventure) do
    state =
      Agent.get_and_update(__MODULE__, fn _ ->
        scenes = Initialize.build_all(adventure)
        state = %State{scenes: scenes}
        {state, %__MODULE__{state: state}}
      end)

    broadcast_game_update(state)
    {:ok, state}
  end

  def run_action(action, data) when is_list(action) do
    case run_action_in_agent_update(action, data) do
      {:ok, state} ->
        broadcast_game_update(state)
        :ok

      error ->
        error
    end
  end

  defp run_action_in_agent_update(action, data) when is_list(action) do
    Agent.get_and_update(__MODULE__, fn
      %__MODULE__{state: %State{} = state} = game ->
        case Actions.action(state, action, data) do
          {:ok, new_state} -> {{:ok, new_state}, %__MODULE__{state: new_state}}
          error -> {error, game}
        end

      game ->
        {{:error, "No adventure loaded"}, game}
    end)
  end

  defp broadcast_game_update(%State{} = state) do
    broadcast(%{game_update: %{scene: State.scene(state)}})
  end
end
