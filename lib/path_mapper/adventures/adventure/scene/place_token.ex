defmodule PathMapper.Adventures.Adventure.Scene.PlaceToken do
  use Ecto.Schema

  import Ecto.Changeset

  require PathMapper.TokenStates
  import PathMapper.TokenStates, only: [states: 0]

  @primary_key false

  embedded_schema do
    field(:game_id, :string)
    field(:name, :string)
    field(:x, :float)
    field(:y, :float)
    field(:state, :string)
    field(:owner, :string)
  end

  def changeset(struct, params) do
    struct
    |> cast(params, [:game_id, :name, :x, :y, :state, :owner])
    |> validate_required([:game_id, :x, :y])
    |> validate_inclusion(:state, states())
  end
end
