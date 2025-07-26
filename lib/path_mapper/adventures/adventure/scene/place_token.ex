defmodule PathMapper.Adventures.Adventure.Scene.PlaceToken do
  use Ecto.Schema

  require PathMapper.Game.State.Scene.Token

  import Ecto.Changeset
  import PathMapper.Game.State.Scene.Token, only: [states: 0]

  @primary_key false

  embedded_schema do
    field(:name, :string)
    field(:x, :integer)
    field(:y, :integer)
    field(:state, :string)
  end

  def changeset(struct, params) do
    struct
    |> cast(params, [:name, :x, :y, :state])
    |> validate_required([:name, :x, :y])
    |> validate_inclusion(:state, states())
  end
end
