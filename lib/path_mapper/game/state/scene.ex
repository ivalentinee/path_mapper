defmodule PathMapper.Game.State.Scene do
  use Ecto.Schema

  alias PathMapper.Adventures.Adventure
  alias PathMapper.Adventures.Adventure.Scene, as: AdventureScene

  @primary_key false

  embedded_schema do
    field(:id, :string)
    field(:order, :integer)
    field(:custom, :boolean, default: false)
    field(:uploaded_map, :boolean, default: false)
    field(:name, :string)
    embeds_one(:map, __MODULE__.Map)
    embeds_one(:data, AdventureScene)
    embeds_many(:tokens, __MODULE__.Token)
    embeds_many(:drawn_elements, __MODULE__.DrawnElement)
  end

  @doc """
  The map a scene shows: its own when a map was uploaded onto it, the
  adventure blob's otherwise.
  """
  def displayed_map(scene, adventure)

  def displayed_map(%__MODULE__{uploaded_map: true} = scene, _adventure), do: data_map(scene)

  def displayed_map(%__MODULE__{} = scene, adventure) do
    (adventure && blob_map(adventure, scene.id)) || data_map(scene)
  end

  defp blob_map(adventure, id) do
    case Adventure.find_scene_by_id(adventure, id) do
      %{map: map} -> map
      _ -> nil
    end
  end

  defp data_map(%__MODULE__{data: %{map: map}}) when not is_nil(map), do: map
  defp data_map(_scene), do: nil

  def initialize(%AdventureScene{map: map} = adventure_scene, order) do
    %__MODULE__{
      id: adventure_scene.id,
      order: order,
      name: adventure_scene.name,
      data: adventure_scene,
      map: __MODULE__.Map.initialize(map),
      tokens: [],
      drawn_elements: []
    }
  end

  def initialize_custom(name, order, id \\ nil) when is_binary(name) do
    %__MODULE__{
      id: id || PathMapper.Id.generate("sc9999"),
      order: order,
      custom: true,
      name: name,
      data: nil,
      map: __MODULE__.Map.blank(),
      tokens: [],
      drawn_elements: []
    }
  end
end
