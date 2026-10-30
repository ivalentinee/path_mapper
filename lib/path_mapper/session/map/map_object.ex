defmodule PathMapper.Session.Map.MapObject do
  use Ecto.Schema

  import Ecto.Changeset
  alias PathMapper.UploadStorage, as: FileStorage

  @primary_key false

  embedded_schema do
    field(:name, :string)
    field(:image, :binary)
    field(:x, :integer)
    field(:y, :integer)
    field(:width, :integer)
    field(:height, :integer)
    field(:layer_index, :integer)
    field(:tags, {:array, :string})
    field(:show, :boolean)
    embeds_one(:link, __MODULE__.Link)
  end

  def changeset(struct, params) do
    struct
    |> cast(params, [:name, :image, :x, :y, :width, :height, :layer_index, :tags])
    |> cast_show()
    |> cast_link()
    |> FileStorage.store_image(:image)
    |> validate_required([:name, :image, :x, :y, :width, :height, :layer_index, :tags, :show])
  end

  defp cast_show(changeset) do
    tags = get_change(changeset, :tags) || []
    show = !Enum.any?(tags, &(&1 == "hide"))
    put_change(changeset, :show, show)
  end

  # Read from the tags the object already carries, beside `show`, which is the
  # precedent for deriving a field from them.
  defp cast_link(changeset) do
    case __MODULE__.Link.from_tags(get_change(changeset, :tags) || []) do
      nil -> changeset
      link -> put_change(changeset, :link, link)
    end
  end
end
