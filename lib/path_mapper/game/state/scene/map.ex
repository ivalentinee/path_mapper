defmodule PathMapper.Game.State.Scene.Map do
  use Ecto.Schema

  alias PathMapper.Adventures.Adventure.Scene.Map, as: AdventureMap

  @primary_key false

  embedded_schema do
    embeds_many(:layers, __MODULE__.Layer)
  end

  def initialize(%AdventureMap{layers: layers}) do
    %__MODULE__{layers: Enum.map(Enum.with_index(layers), &__MODULE__.Layer.initialize/1)}
  end
end
