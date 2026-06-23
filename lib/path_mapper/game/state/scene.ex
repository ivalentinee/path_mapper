defmodule PathMapper.Game.State.Scene do
  use Ecto.Schema

  alias PathMapper.Adventures.Adventure.Scene, as: AdventureScene

  @primary_key false

  embedded_schema do
    field(:index, :integer)
    field(:custom, :boolean, default: false)
    field(:name, :string)
    embeds_one(:map, __MODULE__.Map)
    embeds_one(:data, AdventureScene)
    embeds_many(:tokens, __MODULE__.Token)
    embeds_many(:drawn_elements, __MODULE__.DrawnElement)
  end

  def initialize(%AdventureScene{map: map} = adventure_scene, index) do
    %__MODULE__{
      index: index,
      name: adventure_scene.name,
      data: adventure_scene,
      map: __MODULE__.Map.initialize(map),
      tokens: [],
      drawn_elements: []
    }
  end

  def initialize_custom(name, index) when is_binary(name) do
    %__MODULE__{
      index: index,
      custom: true,
      name: name,
      data: nil,
      map: __MODULE__.Map.blank(),
      tokens: [],
      drawn_elements: []
    }
  end
end
