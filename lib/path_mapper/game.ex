defmodule PathMapper.Game do
  @moduledoc """
  What has happened in the session, and the one channel that says it changed.

  Game state is held in one Agent and every change — a command, or the store
  gaining or losing a piece — ends in a single `game_update` broadcast. There
  used to be three topics, one here and one each for adventures and groups;
  those existed because an adventure and a group were declarations no surface
  carried a copy of. With both gone, and the wallpaper held in state beside the
  surfaces, one topic carries everything.
  """

  defstruct [:state]

  use Agent

  alias __MODULE__.Actions
  alias __MODULE__.Dump
  alias __MODULE__.Palette
  alias __MODULE__.Restore
  alias __MODULE__.State
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

  def get_state(viewed_surface_id \\ nil) do
    Agent.get(__MODULE__, fn
      %__MODULE__{state: %State{} = state} -> rendered(state, viewed_surface_id)
      _ -> nil
    end)
  end

  @doc """
  Brings game state into line with the entity store.

  Called whenever a command changes what the session is made of. A map the store
  gained becomes a surface; one it lost goes; one re-declared under the same id
  keeps what was placed and drawn on it while taking the new declaration's
  geometry. The wallpaper and the palette are read across at the same time, so a
  change to either reaches a view by the same broadcast.

  Game state's copy of a declaration is written here and nowhere else, which is
  the rule that keeps the copy honest.
  """
  def reconcile do
    declared = Resolve.surfaces()
    wallpaper = Resolve.wallpaper()

    Resolve.characters() |> Palette.build() |> Palette.store()

    Agent.update(__MODULE__, fn held ->
      %__MODULE__{state: reconciled(held_state(held), declared, wallpaper)}
    end)

    broadcast_game_update(get_raw_state())
    :ok
  end

  defp held_state(%__MODULE__{state: %State{} = state}), do: state
  defp held_state(_held), do: %State{surfaces: %{}}

  defp reconciled(%State{} = state, declared, wallpaper) do
    surfaces =
      Map.new(declared, fn map -> {map.id, reconciled_surface(state.surfaces[map.id], map)} end)

    %{
      state
      | surfaces: surfaces,
        wallpaper: wallpaper,
        active_surface: surviving_active(state.active_surface, surfaces)
    }
  end

  defp reconciled_surface(nil, map), do: State.Surface.initialize(map)
  defp reconciled_surface(%State.Surface{} = held, map), do: State.Surface.rebuild(held, map)

  defp surviving_active(nil, _surfaces), do: nil

  defp surviving_active(id, surfaces), do: if(Map.has_key?(surfaces, id), do: id, else: nil)

  @doc false
  def get_raw_state_for_test, do: get_raw_state()

  defp get_raw_state do
    Agent.get(__MODULE__, fn
      %__MODULE__{state: %State{} = state} -> state
      _ -> %State{surfaces: %{}}
    end)
  end

  def clear do
    Agent.update(__MODULE__, fn _ -> nil end)

    Store.clear()
    PathMapper.Charkeeper.stop()
    Palette.build(nil) |> Palette.store()
    PathMapper.UploadStorage.clear()
    broadcast(%{game_update: nil})
    :ok
  end

  @doc """
  Runs one command against game state.

  Answers `:ok`, or `{:ok, warnings}` where the command was accepted but part of
  it was declined. A command is never half-refused: what could be done was done,
  and the warnings say what was not.
  """
  def run_action(action, data) when is_list(action) do
    case run_action_in_agent_update(action, data) do
      {:ok, state} ->
        broadcast_game_update(state)
        :ok

      {:ok, state, []} ->
        broadcast_game_update(state)
        :ok

      {:ok, state, warnings} ->
        broadcast_game_update(state)
        {:ok, warnings}

      error ->
        error
    end
  end

  defp run_action_in_agent_update(action, data) when is_list(action) do
    Agent.get_and_update(__MODULE__, fn
      %__MODULE__{state: %State{} = state} = game ->
        case Actions.action(state, action, data) do
          {:ok, new_state} ->
            {{:ok, new_state}, %__MODULE__{state: new_state}}

          {:ok, new_state, warnings} ->
            {{:ok, new_state, warnings}, %__MODULE__{state: new_state}}

          error ->
            {error, game}
        end

      game ->
        {{:error, "The session holds nothing yet"}, game}
    end)
  end

  def dump_state do
    Agent.get(__MODULE__, fn
      %__MODULE__{state: %State{} = state} -> {:ok, Dump.serialize(state)}
      _ -> {:error, "No game state to dump"}
    end)
  end

  @doc """
  Applies a snapshot, then reconciles against the store.

  A snapshot asserts nothing about where it came from: it names surfaces and
  tokens by id, and what it names that the store does not hold is simply not
  restored. Reconciling afterwards is what keeps every declared map in the game
  master's list, which applying alone would not — the snapshot knows only what
  was on a surface, never which surfaces exist.
  """
  def restore_state(manifest) when is_map(manifest) do
    with {:ok, snapshot} <- Restore.read(manifest),
         {:ok, new_state} <- Restore.build(snapshot.data) do
      Agent.update(__MODULE__, fn _ -> %__MODULE__{state: new_state} end)
      reconcile()
      :ok
    end
  end

  defp broadcast_game_update(%State{} = state) do
    broadcast(%{game_update: rendered(state, nil)})
  end

  # A page at a surface's own address renders the surface it names in place of
  # the table's, and nothing else differs - so the substitution happens here,
  # once, and no component learns that a page can be looking elsewhere.
  #
  # `active_surface_id` survives the substitution because the page needs it:
  # the button that pushes a surface to the table is absent where there is
  # nothing to push, which is a comparison against what the table is shown.
  defp rendered(%State{} = state, viewed_surface_id) do
    %{
      surface: viewed_surface(state, viewed_surface_id),
      active_surface_id: state.active_surface,
      wallpaper: state.wallpaper,
      initiative: state.initiative,
      surface_list: build_surface_list(state)
    }
  end

  defp viewed_surface(%State{} = state, nil), do: State.surface(state)
  defp viewed_surface(%State{surfaces: surfaces}, id), do: Map.get(surfaces, id)

  @doc """
  The surface a keyboard access index names, or nil.

  The access index is a position in what is currently on screen. It is derived
  here rather than stored, because it changes whenever the ordering does and an
  id does not.
  """
  def surface_id_at(position) when is_integer(position) and position > 0 do
    case Agent.get(__MODULE__, & &1) do
      %__MODULE__{state: %State{} = state} ->
        case state |> State.ordered() |> Enum.at(position - 1) do
          %State.Surface{id: id} -> id
          nil -> nil
        end

      _ ->
        nil
    end
  end

  def surface_id_at(_position), do: nil

  @doc """
  The game id of the placement at a position on the active surface, counting
  from 1.

  A keystroke names a placement by the number shown on it, which is its position
  in the surface's list. Commands address placements by id, so the number a game
  master types is resolved here rather than reaching the action layer.
  """
  def placement_id_at(position) when is_integer(position) and position > 0 do
    case Agent.get(__MODULE__, & &1) do
      %__MODULE__{state: %State{} = state} ->
        case state |> State.surface() |> Elixir.Map.get(:tokens, []) |> Enum.at(position - 1) do
          %State.Surface.Token{game_id: game_id} -> game_id
          nil -> nil
        end

      _ ->
        nil
    end
  end

  def placement_id_at(_position), do: nil

  @doc "Whether the store holds a surface under this id."
  def surface?(id) when is_binary(id) do
    Agent.get(__MODULE__, fn
      %__MODULE__{state: %State{surfaces: surfaces}} -> Map.has_key?(surfaces, id)
      _ -> false
    end)
  end

  defp build_surface_list(%State{} = state) do
    state
    |> State.ordered()
    |> Enum.map(&%{id: &1.id, name: &1.name})
  end
end
