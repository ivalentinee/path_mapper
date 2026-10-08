defmodule PathMapper.Game.State.Surface.Map do
  use Ecto.Schema

  alias PathMapper.Session.Map, as: AdventureMap

  @primary_key false

  embedded_schema do
    field(:width, :integer)
    field(:height, :integer)
    field(:grid_size, :integer)
    field(:grid_line_width, :integer)
    field(:show_grid, :boolean)
    embeds_many(:layers, __MODULE__.Layer)
    embeds_many(:map_objects, __MODULE__.MapObject)
  end

  @doc """
  The live map a surface starts with.

  It carries the map's size as well as its grid, because this is the only map
  the board reads: the declaration is kept beside it for what a re-upload should
  be merged against, not for anything to measure by. There is no blank form —
  a surface is a map, so a surface with no map cannot exist.
  """
  def initialize(%AdventureMap{} = map) do
    %__MODULE__{
      width: map.width,
      height: map.height,
      grid_size: map.grid_size,
      grid_line_width: map.grid_line_width,
      show_grid: map.show_grid,
      layers: Enum.map(Enum.with_index(map.layers || []), &__MODULE__.Layer.initialize/1),
      map_objects:
        (map.map_objects || [])
        |> Enum.with_index()
        |> Enum.map(&__MODULE__.MapObject.initialize/1)
    }
  end
end
