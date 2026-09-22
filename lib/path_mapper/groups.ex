defmodule PathMapper.Groups do
  @moduledoc """
  The group the session holds, as a view over the entity store.
  """

  alias PathMapper.Game.Palette
  alias PathMapper.Groups.Group
  alias PathMapper.Session.Resolve
  alias Phoenix.PubSub

  @update_pubsub_topic "groups"
  @group_loaded_event :group_loaded

  def subscribe, do: PubSub.subscribe(PathMapper.PubSub, @update_pubsub_topic)

  def broadcast(event), do: PubSub.broadcast(PathMapper.PubSub, @update_pubsub_topic, event)

  def get_loaded, do: Resolve.group()

  @doc """
  Every token id the loaded group's players carry, their own and their markings.

  A player's tokens are placed through the player's own panels, which know that
  their character goes down once and a marking as often as asked. Somewhere that
  offers tokens generally should leave these out rather than offer a second route
  that knows neither rule.
  """
  def player_token_ids do
    case get_loaded() do
      {:ok, %Group{players: players}} when is_list(players) ->
        Enum.flat_map(players, fn player ->
          [player.token_id | Enum.map(player.extra_tokens || [], & &1.id)]
        end)
        |> Enum.reject(&is_nil/1)
        |> MapSet.new()

      _ ->
        MapSet.new()
    end
  end

  @doc """
  Brings the palette and the character pollers into line with the group the store
  now holds.

  Reconciled rather than fired: a group is built by several commands, so there is
  no moment at which it becomes complete, and inventing one would be a mode.
  """
  def reconcile do
    group =
      case Resolve.group() do
        {:ok, group} -> group
        {:error, _reason} -> nil
      end

    group |> Palette.build() |> Palette.store()
    PathMapper.Charkeeper.start_or_restart((group && group.players) || [])
    broadcast(%{@group_loaded_event => group})
    :ok
  end
end
