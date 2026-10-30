defmodule PathMapperWeb.ViewedSurface do
  @moduledoc """
  A page showing a surface that is not the table's.

  Every page already receives one surface, resolved by `Game.get_state/1` — so
  a page at a surface's own address asks for a different one and renders
  identically. One substitution, no second rendering path, and no component
  knows the difference.

  What the substitution must not hide is what the table is actually shown: the
  button that pushes a surface to the table is absent when there is nothing to
  push, and that is a comparison. So the rendered state carries
  `active_surface_id` alongside the surface being looked at.
  """

  defmodule NotFound do
    @moduledoc "An address naming a surface the store does not hold."
    defexception [:message, plug_status: 404]
  end

  @doc """
  The state a page should hold after a broadcast.

  A broadcast carries the table's surface, because that is what it is about.
  A page looking elsewhere asks again for its own, which costs one Agent read
  and keeps the page on the surface its address names.
  """
  def rendered(broadcast_state, nil), do: broadcast_state
  def rendered(_broadcast_state, id) when is_binary(id), do: PathMapper.Game.get_state(id)

  @doc "Refuses at open time, where an empty board would be mistaken for a failed load."
  def check!(nil), do: :ok

  def check!(id) when is_binary(id) do
    if PathMapper.Game.surface?(id), do: :ok, else: raise(NotFound, "No surface at #{id}")
  end

  @doc "Whether this page shows something the table is not already shown."
  def pushable?(%{active_surface_id: active}, id) when is_binary(id), do: active != id
  def pushable?(_state, _id), do: false
end
