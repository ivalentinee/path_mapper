defmodule PathMapper.Adventures.Adventure.Scene.PlaceToken do
  use Ecto.Schema

  import Ecto.Changeset

  require PathMapper.TokenStates
  import PathMapper.TokenStates, only: [states: 0]

  @primary_key false

  embedded_schema do
    field(:id, :string)
    field(:x, :integer)
    field(:y, :integer)
    field(:state, :string)
    field(:subpixel, :integer)
  end

  def changeset(struct, params) do
    struct
    |> cast(params, [:id, :x, :y, :state, :subpixel])
    |> validate_required([:id, :x, :y])
    |> validate_inclusion(:state, states())
  end
end
