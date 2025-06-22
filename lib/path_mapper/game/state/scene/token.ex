defmodule PathMapper.Game.State.Scene.Token do
  use Ecto.Schema

  @states ["alive", "unconscious", "dead"]

  @primary_key false

  embedded_schema do
    field(:x, :integer)
    field(:y, :integer)
    field(:state, :string)
    field(:drag_x, :integer)
    field(:drag_y, :integer)
    field(:size, :integer)
    field(:color, :string)
    embeds_one(:data, PathMapper.Tokens.Token)
  end

  defmacro states, do: @states
end
