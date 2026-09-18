defmodule PathMapper.Groups.Group.Player do
  use Ecto.Schema

  alias PathMapper.StoredAsset

  import Ecto.Changeset

  @primary_key false

  embedded_schema do
    field(:id, :string)
    field(:character_name, :string)
    field(:player_name, :string)
    field(:color, :string)
    field(:class, :string)
    field(:token, :string)
    field(:token_id, :string)
    field(:charkeeper_id, :string)
    embeds_many(:extra_tokens, __MODULE__.ExtraToken)
  end

  def changeset(struct, params) do
    struct
    |> cast(params, [
      :id,
      :token_id,
      :character_name,
      :player_name,
      :color,
      :class,
      :token,
      :charkeeper_id
    ])
    |> StoredAsset.validate(:token)
    |> validate_required([:id, :token_id, :character_name, :player_name, :color, :token])
    |> cast_embed(:extra_tokens)
  end
end
