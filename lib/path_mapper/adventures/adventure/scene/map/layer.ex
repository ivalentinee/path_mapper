defmodule PathMapper.Adventures.Adventure.Scene.Map.Layer do
  use Ecto.Schema

  import Ecto.Changeset

  @primary_key false

  embedded_schema do
    field(:name, :string)
    field(:src, :binary)
    field(:index, :integer)
    field(:x, :integer)
    field(:y, :integer)
    field(:tags, {:array, :string})
  end

  def changeset(struct, params) do
    struct
    |> cast(params, [:name, :src, :index, :x, :y, :tags])
    |> validate_required([:name, :src, :index, :x, :y])
  end
end
