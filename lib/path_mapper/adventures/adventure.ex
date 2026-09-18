defmodule PathMapper.Adventures.Adventure do
  use Ecto.Schema

  import Ecto.Changeset
  alias PathMapper.StoredAsset

  @primary_key false

  embedded_schema do
    field(:id, :string)
    field(:title, :string)
    field(:wallpaper, :string)
    field(:file, :string)
    embeds_many(:urls, __MODULE__.URL)
    embeds_many(:scenes, __MODULE__.Scene)
  end

  def get_scene(%__MODULE__{scenes: scenes}, scene_index) when is_number(scene_index) do
    if adventure_scene = Enum.at(scenes, scene_index) do
      {:ok, adventure_scene}
    else
      {:error, "Scene ##{scene_index} not found"}
    end
  end

  def get_scene_map(%__MODULE__{scenes: scenes}, scene_index) when is_number(scene_index) do
    case Enum.at(scenes, scene_index) do
      nil -> nil
      scene -> scene.map
    end
  end

  def all_tokens(%__MODULE__{scenes: scenes}) do
    scenes
    |> Enum.flat_map(fn scene -> scene.tokens || [] end)
    |> Enum.uniq_by(& &1.id)
    |> Enum.sort_by(& &1.name)
  end

  def find_token_by_id(%__MODULE__{scenes: scenes}, id) when is_binary(id) do
    Enum.find_value(scenes, fn scene ->
      Enum.find(scene.tokens || [], &(&1.id == id))
    end)
  end

  def find_token_by_id(%__MODULE__{}, _id), do: nil

  def find_scene_by_id(%__MODULE__{scenes: scenes}, id) when is_binary(id) do
    Enum.find(scenes, &(&1.id == id))
  end

  def find_scene_by_id(%__MODULE__{}, _id), do: nil

  def changeset(struct, params) do
    struct
    |> cast(params, [:id, :title, :wallpaper, :file])
    |> StoredAsset.validate(:wallpaper)
    |> cast_embed(:urls)
    |> validate_required([:id, :title])
  end
end
