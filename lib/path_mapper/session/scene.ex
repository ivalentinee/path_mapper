defmodule PathMapper.Session.Scene do
  @moduledoc """
  A scene as the store holds it: names rather than contents.

  It refers to its map and its tokens by id, because those are entities in their
  own right and a token in particular is shared - the same token appears in other
  scenes, other adventures, and sometimes in another role. A scene that embedded
  them would be claiming to own them.

  `order` is explicit rather than read off the id. A zero-padded id leaves no room
  between neighbours, so deriving order would make inserting a scene a renumbering,
  and stable ids exist to prevent exactly that.
  """

  use Ecto.Schema

  import Ecto.Changeset

  @primary_key false

  embedded_schema do
    field(:id, :string)
    field(:ref, :string)
    field(:name, :string)
    field(:type, :string)
    field(:order, :integer)
    field(:map_id, :string)
    embeds_many(:tokens, __MODULE__.TokenRef)
    embeds_many(:place_tokens, PathMapper.Adventures.Adventure.Scene.PlaceToken)
  end

  def changeset(struct, params) do
    struct
    |> cast(params, [:id, :ref, :name, :type, :order, :map_id])
    |> cast_embed(:tokens)
    |> cast_embed(:place_tokens)
    |> validate_required([:id, :name, :order])
  end

  defmodule TokenRef do
    @moduledoc """
    A token used in a scene, and how this scene uses it.

    The token carries its own name, size and owner; anything set here overrides
    them for this scene alone. That is what lets one token be an NPC by default and
    a player's where a scene says so, without becoming two tokens.
    """

    use Ecto.Schema

    import Ecto.Changeset

    @primary_key false

    embedded_schema do
      field(:id, :string)
      field(:name, :string)
      field(:owner, :string)
      field(:size, :integer)
    end

    def changeset(struct, params) do
      struct
      |> cast(params, [:id, :name, :owner, :size])
      |> validate_required([:id])
    end
  end
end
