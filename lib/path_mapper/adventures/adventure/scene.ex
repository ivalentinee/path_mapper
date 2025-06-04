defmodule PathMapper.Adventures.Adventure.Scene do
  use Ecto.Schema

  import Ecto.Changeset

  @scene_types ["battle"]

  @primary_key false

  embedded_schema do
    field(:name, :string)
    field(:type, :string)
    embeds_one(:map, __MODULE__.Map)
  end

  def changeset(struct, params, adventure_zip) do
    struct
    |> cast(params, [:name, :type])
    |> validate_required([:name, :type])
    |> validate_inclusion(:type, @scene_types)
    |> cast_embed(:map, required: true, with: &__MODULE__.Map.changeset(&1, &2, adventure_zip))
  end
end
