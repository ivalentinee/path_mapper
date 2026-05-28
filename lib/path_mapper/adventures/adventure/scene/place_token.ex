defmodule PathMapper.Adventures.Adventure.Scene.PlaceToken do
  use Ecto.Schema

  import Ecto.Changeset

  require PathMapper.TokenStates
  import PathMapper.TokenStates, only: [states: 0]

  @primary_key false

  embedded_schema do
    field(:name, :string)
    field(:x, :integer)
    field(:y, :integer)
    field(:state, :string)
    field(:subpixel, :integer)
  end

  def changeset(struct, params) do
    struct
    |> cast(params, [:name, :x, :y, :state, :subpixel])
    |> validate_required([:name, :x, :y])
    |> validate_inclusion(:state, states())
  end
end
