defmodule PathMapper.Game.State.Scene.DrawnElement do
  use Ecto.Schema

  @primary_key false

  # type validation is enforced by guard clauses in Actions.Draw,
  # Ecto.Enum here serves as documentation of valid values
  embedded_schema do
    field(:id, :string)
    field(:type, Ecto.Enum, values: [:fill, :rect, :line, :circle, :text])
    field(:color, :string)
    field(:owner, :string)
    field(:data, :map)
  end
end
