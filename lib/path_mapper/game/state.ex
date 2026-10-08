defmodule PathMapper.Game.State do
  @moduledoc """
  What has happened in a session, as distinct from what the session is made of.

  Surfaces are keyed by map id and `active_surface` holds one, because a placement
  has to survive leaving a surface and coming back — so it cannot belong to the
  surface being looked at, and it cannot be found by a position that changes when
  a map is added. Nothing here is an access path: where an ordering or a lookup
  wants to be fast, that is a job for data management rather than for this shape.

  `wallpaper` is the one declaration held here that no surface carries. It is what
  a viewer sees when none is active, and it lives in state so that a wallpaper
  changing in the store reaches a connected view by the one channel every other
  change already travels.
  """

  use Ecto.Schema

  @primary_key false

  embedded_schema do
    field(:active_surface, :string)
    field(:surfaces, :map, default: %{})
    field(:initiative, {:array, :map}, default: [])
    embeds_one(:wallpaper, PathMapper.Session.Wallpaper)
  end

  def surface(%__MODULE__{active_surface: nil}), do: nil

  def surface(%__MODULE__{active_surface: id, surfaces: surfaces}) do
    Map.get(surfaces, id)
  end

  def put_surface(%__MODULE__{active_surface: nil}, _surface) do
    raise "put_surface called with no active surface"
  end

  def put_surface(%__MODULE__{active_surface: id} = state, %__MODULE__.Surface{} = surface)
      when is_binary(id) do
    Map.update!(state, :surfaces, &Map.put(&1, id, surface))
  end

  @doc """
  Surfaces in id order.

  Nothing carries a position of its own: ids are fixed-width and zero-padded, so
  the string sort is the numeric one and the game master orders the list by
  naming the files.
  """
  def ordered(%__MODULE__{surfaces: surfaces}) do
    surfaces |> Map.values() |> Enum.sort_by(& &1.id)
  end
end
