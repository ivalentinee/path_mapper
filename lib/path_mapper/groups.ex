defmodule PathMapper.Groups do
  @moduledoc """
  The group the session holds, as a view over the entity store.
  """

  alias PathMapper.Game.Palette
  alias PathMapper.Session.Resolve
  alias Phoenix.PubSub

  @update_pubsub_topic "groups"
  @group_loaded_event :group_loaded

  def subscribe, do: PubSub.subscribe(PathMapper.PubSub, @update_pubsub_topic)

  def broadcast(event), do: PubSub.broadcast(PathMapper.PubSub, @update_pubsub_topic, event)

  def get_loaded, do: Resolve.group()

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
