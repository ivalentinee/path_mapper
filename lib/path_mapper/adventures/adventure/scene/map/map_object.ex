defmodule PathMapper.Adventures.Adventure.Scene.Map.MapObject do
  use Ecto.Schema

  import Ecto.Changeset
  alias PathMapper.Adventures.Adventure.FileStorage

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
  end

  def changeset(struct, params) do
    struct
    |> cast(params, [:name, :image, :x, :y, :width, :height, :layer_index, :tags])
    |> cast_show()
    |> FileStorage.store_image(:image)
    |> validate_required([:name, :image, :x, :y, :width, :height, :layer_index, :tags, :show])
  end

  defp cast_show(changeset) do
    tags = get_change(changeset, :tags) || []
    show = !Enum.any?(tags, &(&1 == "hide"))
    put_change(changeset, :show, show)
  end
end
