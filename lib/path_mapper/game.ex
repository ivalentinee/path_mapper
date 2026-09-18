defmodule PathMapper.Game do
  defstruct [:state]

  use Agent

  alias __MODULE__.Actions
  alias __MODULE__.Dump
  alias __MODULE__.Initialize
  alias __MODULE__.Palette
  alias __MODULE__.Restore
  alias __MODULE__.State
  alias PathMapper.Adventures
  alias PathMapper.Groups
  alias PathMapper.Session.Resolve
  alias PathMapper.Session.Store
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
      %__MODULE__{state: %State{} = state} ->
        %{
          scene: State.scene(state),
          initiative: state.initiative,
          scene_list: build_scene_list(state)
        }

      _ ->
        nil
    end)
  end

  @doc """
  Brings game state into line with the entity store.

  Called whenever a command changes what the session is made of. A scene the store
  gained appears; one it lost goes; one whose declaration changed has its copy in
  state refreshed. The copy exists so that every reader of a scene did not have to
  move to the store at once, and this is the rule that keeps it honest: nothing
  writes it except here.
  """
  def reconcile do
    declared = Resolve.scenes()

    Agent.update(__MODULE__, fn held ->
      state = held_state(held)
      %__MODULE__{state: reconciled(state, declared)}
    end)

    Groups.reconcile()
    Adventures.announce()
    broadcast_game_update(get_raw_state())
    :ok
  end

  defp held_state(%__MODULE__{state: %State{} = state}), do: state
  defp held_state(_held), do: %State{scenes: %{}}

  defp reconciled(%State{} = state, declared) do
    scenes =
      declared
      |> Enum.with_index()
      |> Map.new(fn {adventure_scene, order} ->
        {adventure_scene.id,
         reconciled_scene(state.scenes[adventure_scene.id], adventure_scene, order)}
      end)

    custom = for {id, scene} <- state.scenes, scene.custom, into: %{}, do: {id, scene}
    scenes = Map.merge(custom, scenes)

    %{state | scenes: scenes, active_scene: surviving_active(state.active_scene, scenes)}
  end

  defp reconciled_scene(nil, adventure_scene, order) do
    Initialize.build_scene(adventure_scene, order)
  end

  defp reconciled_scene(%State.Scene{} = held, adventure_scene, order) do
    %{held | data: adventure_scene, order: order, name: adventure_scene.name}
  end

  defp surviving_active(nil, _scenes), do: nil

  defp surviving_active(id, scenes), do: if(Map.has_key?(scenes, id), do: id, else: nil)

  defp get_raw_state do
    Agent.get(__MODULE__, fn
      %__MODULE__{state: %State{} = state} -> state
      _ -> %State{scenes: %{}}
    end)
  end

  def clear do
    Agent.update(__MODULE__, fn _ -> nil end)

    Store.clear()
    PathMapper.Charkeeper.stop()
    Palette.build(nil) |> Palette.store()
    PathMapper.UploadStorage.clear()
    broadcast(%{game_update: nil})
    broadcast(%{adventure_loaded: nil})
    :ok
  end

  def reset_empty do
    state =
      Agent.get_and_update(__MODULE__, fn _ ->
        state = %State{scenes: %{}}
        {state, %__MODULE__{state: state}}
      end)

    broadcast_game_update(state)
    {:ok, state}
  end

  def reset(%PathMapper.Adventures.Adventure{} = adventure) do
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

  def dump_state do
    Agent.get(__MODULE__, fn
      %__MODULE__{state: %State{} = state} ->
        with {:ok, adventure} <- Adventures.get_loaded() do
          group =
            case Groups.get_loaded() do
              {:ok, group} -> group
              _ -> nil
            end

          group_id = if group, do: group.id
          {:ok, Dump.serialize(state, adventure, group_id)}
        end

      _ ->
        {:error, "No game state to dump"}
    end)
  end

  def restore_state(manifest) when is_map(manifest) do
    with {:ok, snapshot} <- Restore.read(manifest),
         {:ok, adventure} <- match_loaded_adventure(snapshot.adventure_id),
         :ok <- match_loaded_group(snapshot.group_id),
         {:ok, new_state} <- Restore.build(snapshot.data, adventure) do
      Agent.update(__MODULE__, fn _ -> %__MODULE__{state: new_state} end)
      Groups.reconcile()
      broadcast_game_update(new_state)
      :ok
    end
  end

  # A snapshot names the blobs it wants; it does not carry them, and the server has
  # no library to fetch them from. So restoring matches against what is loaded and
  # refuses a mismatch, rather than loading on the snapshot's behalf.
  defp match_loaded_adventure(id) do
    case Adventures.get_loaded() do
      {:ok, %{id: ^id} = adventure} -> {:ok, adventure}
      {:ok, %{id: other}} -> {:error, "Snapshot wants adventure #{id}, but #{other} is loaded"}
      _ -> {:error, "Snapshot wants adventure #{id}, but none is loaded"}
    end
  end

  defp match_loaded_group(nil), do: :ok

  defp match_loaded_group(id) when is_binary(id) do
    case Groups.get_loaded() do
      {:ok, %{id: ^id}} -> :ok
      {:ok, %{id: other}} -> {:error, "Snapshot wants group #{id}, but #{other} is loaded"}
      _ -> {:error, "Snapshot wants group #{id}, but none is loaded"}
    end
  end

  defp broadcast_game_update(%State{} = state) do
    broadcast(%{
      game_update: %{
        scene: State.scene(state),
        initiative: state.initiative,
        scene_list: build_scene_list(state)
      }
    })
  end

  @doc """
  The scene a keyboard access index names, or nil.

  The access index is a position in what is currently on screen. It is derived here
  rather than stored, because it changes whenever the ordering does and an id does
  not.
  """
  def scene_id_at(position) when is_integer(position) and position > 0 do
    case Agent.get(__MODULE__, & &1) do
      %__MODULE__{state: %State{} = state} ->
        case state |> State.ordered() |> Enum.at(position - 1) do
          %State.Scene{id: id} -> id
          nil -> nil
        end

      _ ->
        nil
    end
  end

  def scene_id_at(_position), do: nil

  defp build_scene_list(%State{} = state) do
    state
    |> State.ordered()
    |> Enum.map(fn scene ->
      %{id: scene.id, ref: scene_ref(scene), name: scene.name, custom: scene.custom}
    end)
  end

  defp scene_ref(%State.Scene{data: %{ref: ref}}) when is_binary(ref), do: ref
  defp scene_ref(_scene), do: nil
end
