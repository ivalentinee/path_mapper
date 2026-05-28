defmodule PathMapper.Groups.Group.Player do
  use Ecto.Schema

  alias PathMapper.Groups.Group.FileStorage

  import Ecto.Changeset

  @primary_key false

  embedded_schema do
    field(:character_name, :string)
    field(:player_name, :string)
    field(:color, :string)
    field(:class, :string)
    field(:token, :string)
    embeds_many(:extra_tokens, __MODULE__.ExtraToken)
  end

  def changeset(struct, params, group_zip) do
    struct
    |> cast(params, [:character_name, :player_name, :color, :class, :token])
    |> FileStorage.store_image_from_zip(:token, group_zip)
    |> validate_required([:character_name, :player_name, :color, :token])
    |> cast_embed(:extra_tokens, with: &__MODULE__.ExtraToken.changeset(&1, &2, group_zip))
  end
end
