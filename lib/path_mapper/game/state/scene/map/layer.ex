defmodule PathMapper.Game.State.Scene.Map.Layer do
  use Ecto.Schema

  alias PathMapper.Adventures.Adventure.Scene.Map.Layer, as: AdventureLayer

  @primary_key false

  embedded_schema do
    field(:name, :string)
    field(:show, :boolean)
    field(:floor, :integer)
  end

  def initialize(%AdventureLayer{name: name, show: show, floor: floor}) do
    %__MODULE__{name: name, show: show, floor: floor}
  end
end
