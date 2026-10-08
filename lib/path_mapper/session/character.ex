defmodule PathMapper.Session.Character do
  @moduledoc """
  Someone in the game, as the store holds them.

  A character is declared and persists; a *player* is a browser session that has
  claimed one, and is nothing the store knows about. That is why this carries a
  `player_name` and there is no player entity: the name is a convenience for the
  game master, not an identity.

  Tokens are named by id rather than carried. A character whose token has not
  been uploaded yet resolves to nothing and the reading continues, which is what
  lets the pieces arrive in any order.
  """

  use Ecto.Schema

  import Ecto.Changeset

  @primary_key false

  embedded_schema do
    field(:id, :string)
    field(:character_name, :string)
    field(:player_name, :string)
    field(:color, :string)
    field(:class, :string)
    field(:token_id, :string)
    field(:extra_token_ids, {:array, :string}, default: [])
    field(:charkeeper_id, :string)
  end

  def changeset(struct, params) do
    struct
    |> cast(params, [
      :id,
      :character_name,
      :player_name,
      :color,
      :class,
      :token_id,
      :extra_token_ids,
      :charkeeper_id
    ])
    |> validate_required([:id, :color])
  end
end
