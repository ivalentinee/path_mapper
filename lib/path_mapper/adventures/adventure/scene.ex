defmodule PathMapper.Adventures.Adventure.Scene do
  use Ecto.Schema

  import Ecto.Changeset

  @scene_types ["battle"]

  @primary_key false

  embedded_schema do
    field(:name, :string)
    field(:type, :string)
    embeds_one(:map, __MODULE__.Map)
    embeds_many(:tokens, __MODULE__.Token)
    embeds_many(:place_tokens, __MODULE__.PlaceToken)
  end

  def changeset(struct, params, adventure_zip) do
    struct
    |> cast(params, [:name, :type])
    |> validate_required([:name, :type])
    |> validate_inclusion(:type, @scene_types)
    |> cast_embed(:map, required: true, with: &__MODULE__.Map.changeset(&1, &2, adventure_zip))
    |> cast_embed(:tokens, with: &__MODULE__.Token.changeset(&1, &2, adventure_zip))
    |> cast_embed(:place_tokens)
  end
end
