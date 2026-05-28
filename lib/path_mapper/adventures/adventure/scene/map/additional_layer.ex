defmodule PathMapper.Adventures.Adventure.Scene.Map.AdditionalLayer do
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
    field(:tags, {:array, :string})
  end

  def changeset(struct, params) do
    struct
    |> cast(params, [:name, :image, :x, :y, :width, :height, :tags])
    |> FileStorage.store_image(:image)
    |> validate_required([:name, :image, :x, :y])
  end
end
