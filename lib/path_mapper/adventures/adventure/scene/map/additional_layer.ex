defmodule PathMapper.Adventures.Adventure.Scene.Map.AdditionalLayer do
  use Ecto.Schema

  import Ecto.Changeset

  @primary_key false

  embedded_schema do
    field(:name, :string)
    field(:src, :binary)
    field(:x, :integer)
    field(:y, :integer)
  end

  def changeset(struct, params) do
    struct
    |> cast(params, [:name, :src, :x, :y])
    |> validate_required([:name, :src, :x, :y])
  end
end
