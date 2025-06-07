defmodule PathMapper.Adventures.Adventure do
  use Ecto.Schema

  import Ecto.Changeset
  alias PathMapper.Adventures.Adventure.FileStorage
  alias PathMapper.Zip

  @primary_key false

  embedded_schema do
    field(:title, :string)
    field(:wallpaper, :binary)
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

  def changeset(struct, params, adventure_zip) do
    struct
    |> cast(read_manifest_files(params, adventure_zip), [:title, :wallpaper, :file])
    |> cast_embed(:urls)
    |> cast_embed(:scenes,
      required: true,
      with: &__MODULE__.Scene.changeset(&1, &2, adventure_zip)
    )
    |> validate_required([:title, :file])
  end

  defp read_manifest_files(params, adventure_zip) when is_map(params) do
    with filename when is_binary(filename) <- params["wallpaper"],
         {:ok, wallpaper} <- Zip.get_file(adventure_zip, filename),
         {:ok, wallpaper_path} <- FileStorage.store_image(wallpaper) do
      Map.put(params, "wallpaper", wallpaper_path)
    else
      _ -> params
    end
  end
end
