defmodule PathMapper.Game.State.Scene.Map do
  use Ecto.Schema

  alias PathMapper.Adventures.Adventure.Scene.Map, as: AdventureMap

  @primary_key false

  embedded_schema do
    field(:grid_size, :integer)
    field(:show_grid, :boolean)
    embeds_many(:layers, __MODULE__.Layer)
  end

  def initialize(%AdventureMap{layers: layers, grid_size: grid_size, show_grid: show_grid}) do
    %__MODULE__{
      layers: Enum.map(Enum.with_index(layers), &__MODULE__.Layer.initialize/1),
      grid_size: grid_size,
      show_grid: show_grid
    }
  end
end
