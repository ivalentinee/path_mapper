defmodule PathMapper.Adventures.Adventure.Scene do
  use Ecto.Schema

  import Ecto.Changeset

  @scene_types ["battle"]

  @primary_key false

  embedded_schema do
    field(:id, :string)
    field(:ref, :string)
    field(:name, :string)
    field(:type, :string)
    embeds_one(:map, __MODULE__.Map)
    embeds_many(:tokens, __MODULE__.Token)
    embeds_many(:place_tokens, __MODULE__.PlaceToken)
  end

  def changeset(struct, params) do
    struct
    |> cast(params, [:id, :ref, :name, :type])
    |> validate_required([:id, :name, :type])
    |> validate_inclusion(:type, @scene_types)
    |> cast_embed(:map, required: true)
    |> cast_embed(:tokens)
    |> cast_embed(:place_tokens)
  end
end
