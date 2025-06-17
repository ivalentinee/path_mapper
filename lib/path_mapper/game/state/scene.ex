defmodule PathMapper.Game.State.Scene do
  use Ecto.Schema

  alias PathMapper.Adventures.Adventure.Scene, as: AdventureScene

  @primary_key false

  embedded_schema do
    field(:index, :integer)
    embeds_one(:map, __MODULE__.Map)
    embeds_one(:data, AdventureScene)
    embeds_many(:tokens, __MODULE__.Token)
  end

  def initialize(%AdventureScene{map: map} = adventure_scene, index) do
    %__MODULE__{
      index: index,
      data: adventure_scene,
      map: __MODULE__.Map.initialize(map),
      tokens: []
    }
  end
end
