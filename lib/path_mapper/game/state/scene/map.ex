defmodule PathMapper.Game.State.Scene.Map do
  use Ecto.Schema

  alias PathMapper.Adventures.Adventure.Scene.Map, as: AdventureMap

  @primary_key false

  embedded_schema do
    field(:grid_size, :integer)
    field(:grid_line_width, :integer)
    field(:show_grid, :boolean)
    embeds_many(:layers, __MODULE__.Layer)
    embeds_many(:map_objects, __MODULE__.MapObject)
  end

  def initialize(%AdventureMap{
        layers: layers,
        map_objects: map_objects,
        grid_size: grid_size,
        grid_line_width: grid_line_width,
        show_grid: show_grid
      }) do
    %__MODULE__{
      layers: Enum.map(Enum.with_index(layers), &__MODULE__.Layer.initialize/1),
      map_objects:
        (map_objects || [])
        |> Enum.with_index()
        |> Enum.map(&__MODULE__.MapObject.initialize/1),
      grid_size: grid_size,
      grid_line_width: grid_line_width,
      show_grid: show_grid
    }
  end
end
