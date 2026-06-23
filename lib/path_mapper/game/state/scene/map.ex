defmodule PathMapper.Game.State.Scene.Map do
  use Ecto.Schema

  alias PathMapper.Adventures.Adventure.Scene.Map, as: AdventureMap

  @primary_key false

  @blank_grid_columns 30
  @blank_grid_rows 24
  @blank_grid_size 50

  embedded_schema do
    field(:width, :integer)
    field(:height, :integer)
    field(:grid_size, :integer)
    field(:grid_line_width, :integer)
    field(:show_grid, :boolean)
    embeds_many(:layers, __MODULE__.Layer)
    embeds_many(:map_objects, __MODULE__.MapObject)
  end

  def blank do
    %__MODULE__{
      width: @blank_grid_columns * @blank_grid_size,
      height: @blank_grid_rows * @blank_grid_size,
      grid_size: @blank_grid_size,
      grid_line_width: 1,
      show_grid: true,
      layers: [],
      map_objects: []
    }
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
