defmodule PathMapper.Game.State.Surface.Map.Layer do
  use Ecto.Schema

  alias PathMapper.Session.Map.Layer, as: AdventureLayer

  @primary_key false

  embedded_schema do
    field(:index, :integer)
    field(:show, :boolean)
    field(:light, :binary)
    field(:highlight, :boolean)
  end

  def initialize({%AdventureLayer{index: index, show: show, light: light}, _list_position}) do
    %__MODULE__{index: index, show: show, light: light, highlight: false}
  end
end
