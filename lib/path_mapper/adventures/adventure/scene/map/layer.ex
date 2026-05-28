defmodule PathMapper.Adventures.Adventure.Scene.Map.Layer do
  use Ecto.Schema

  import Ecto.Changeset
  alias PathMapper.Adventures.Adventure.FileStorage

  @primary_key false
  @floor_regex ~r/^floor-([0-9]+)$/

  embedded_schema do
    field(:name, :string)
    field(:image, :binary)
    field(:images, {:array, :map}, default: [])
    field(:index, :integer)
    field(:x, :integer)
    field(:y, :integer)
    field(:width, :integer)
    field(:height, :integer)
    field(:tags, {:array, :string})
    field(:show, :boolean)
    field(:light, :binary)
    field(:floor, :integer)
  end

  def changeset(struct, params) do
    struct
    |> cast(params, [:name, :image, :images, :index, :x, :y, :width, :height, :tags])
    |> store_images()
    |> cast_show()
    |> cast_light()
    |> cast_floor()
    |> validate_required([:name, :index, :tags, :show, :light])
  end

  defp store_images(changeset) do
    changeset = FileStorage.store_image(changeset, :image)

    case get_change(changeset, :images) do
      images when is_list(images) ->
        put_change(changeset, :images, Enum.map(images, &store_sub_image/1))

      _ ->
        changeset
    end
  end

  defp store_sub_image(img) do
    case FileStorage.store_image(img.image) do
      {:ok, path} -> Map.put(img, :image, path)
      _ -> Map.put(img, :image, nil)
    end
  end

  def cast_show(changeset) do
    tags = get_change(changeset, :tags) || []
    show = !Enum.any?(tags, &(&1 == "hide"))
    put_change(changeset, :show, show)
  end

  def cast_light(changeset) do
    tags = get_change(changeset, :tags) || []
    dim = Enum.any?(tags, &(&1 == "dim"))
    light = if dim, do: "dim", else: "bright"
    put_change(changeset, :light, light)
  end

  def cast_floor(changeset) do
    tags = get_change(changeset, :tags) || []

    case Enum.find_value(tags, &Regex.run(@floor_regex, &1)) do
      [_, floor_number_string] ->
        put_change(changeset, :floor, String.to_integer(floor_number_string))

      _ ->
        changeset
    end
  end
end
