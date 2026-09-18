defmodule PathMapper.Adventures do
  @moduledoc """
  The adventure the session holds, as a view over the entity store.

  There is no library and no loading: an adventure is built by commands like
  everything else, and this is where the rest of the code asks what the store
  currently amounts to.
  """

  alias PathMapper.Session.Resolve
  alias Phoenix.PubSub

  @update_pubsub_topic "adventures"
  @adventure_loaded_event :adventure_loaded

  def subscribe, do: PubSub.subscribe(PathMapper.PubSub, @update_pubsub_topic)

  def broadcast(event), do: PubSub.broadcast(PathMapper.PubSub, @update_pubsub_topic, event)

  def get_loaded, do: Resolve.adventure()

  def announce do
    case Resolve.adventure() do
      {:ok, adventure} -> broadcast(%{@adventure_loaded_event => adventure})
      {:error, _reason} -> broadcast(%{@adventure_loaded_event => nil})
    end
  end
end
