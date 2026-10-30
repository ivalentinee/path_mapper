defmodule PathMapper.Charkeeper do
  @moduledoc """
  Live character numbers from Charkeeper, for the characters that name one.

  Nothing here decides who is polled or when. `Poller` reads the session store
  on a timer and keeps the last reading in a table; this is where the rest of
  the application asks for it and hears that it changed.
  """

  alias __MODULE__.Poller
  alias Phoenix.PubSub

  @topic "charkeeper"

  def subscribe do
    PubSub.subscribe(PathMapper.PubSub, @topic)
  end

  def broadcast(payload) do
    PubSub.broadcast(PathMapper.PubSub, @topic, %{charkeeper_update: payload})
  end

  @doc "The last reading: `%{data: %{character_id => CharacterData}, status: status}`."
  def get_data, do: Poller.read()

  @doc """
  Forgets the readings, for a session being put away.

  The next tick would find no characters and clear the table on its own, but
  that is up to a poll interval of stale numbers on screen after a reset.
  """
  def clear do
    Poller.forget()
    broadcast(%{data: %{}, status: nil})
  end
end
