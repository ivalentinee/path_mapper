defmodule PathMapper.Game.State.Scene.Map.MapObject do
  use Ecto.Schema

  alias PathMapper.Adventures.Adventure.Scene.Map.MapObject, as: AdventureMapObject
  alias PathMapper.Geometry.Mapper, as: GeometryMapper

  @primary_key false

  embedded_schema do
    field(:index, :integer)
    field(:layer_index, :integer)
    field(:x, :integer)
    field(:y, :integer)
    field(:drag_x, :integer)
    field(:drag_y, :integer)
    field(:locked, :boolean)
    field(:show, :boolean)
  end

  def initialize({%AdventureMapObject{x: x, y: y, layer_index: layer_index, show: show}, index}) do
    %__MODULE__{
      index: index,
      layer_index: layer_index,
      x: GeometryMapper.to_subpixels(x),
      y: GeometryMapper.to_subpixels(y),
      locked: true,
      show: show
    }
  end
end
