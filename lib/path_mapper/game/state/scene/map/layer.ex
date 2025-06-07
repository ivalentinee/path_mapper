defmodule PathMapper.Game.State.Scene.Map.Layer do
  use Ecto.Schema

  alias PathMapper.Adventures.Adventure.Scene.Map.Layer, as: AdventureLayer

  @primary_key false

  embedded_schema do
    field(:index, :integer)
    field(:show, :boolean)
    field(:light, :binary)
    field(:highlight, :boolean)
  end

  def initialize({%AdventureLayer{show: show, light: light}, index}) do
    %__MODULE__{index: index, show: show, light: light, highlight: false}
  end
end
