defmodule PathMapper.Session.Commands do
  @moduledoc """
  The commands that change what a session is made of.

  Two of them. A piece arrives or a piece leaves, and in both cases game state is
  reconciled against the store afterwards so that what has happened on a surface
  follows what the surface now is.

  There is nothing here that builds a piece, and that is the point: the server
  composes nothing, so a command carries what the client already decided. Game
  state changes go elsewhere, through `PathMapper.Game.run_action/2`, and the two
  do not overlap.
  """

  alias PathMapper.Game
  alias PathMapper.Session.Entity
  alias PathMapper.Session.Store

  def put(%Entity{} = entity) do
    with {:ok, stored} <- Store.put(entity) do
      Game.reconcile()
      {:ok, stored}
    end
  end

  def remove(id) when is_binary(id) do
    :ok = Store.delete(id)
    Game.reconcile()
    :ok
  end
end
