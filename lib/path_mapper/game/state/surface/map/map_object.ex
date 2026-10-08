defmodule PathMapper.Game.State.Surface.Map.MapObject do
  use Ecto.Schema

  alias PathMapper.Geometry.Mapper, as: GeometryMapper
  alias PathMapper.Session.Map.MapObject, as: AdventureMapObject

  @primary_key false

  embedded_schema do
    field(:index, :integer)
    field(:name, :string)
    field(:layer_index, :integer)
    field(:x, :integer)
    field(:y, :integer)
    field(:drag_x, :integer)
    field(:drag_y, :integer)
    field(:locked, :boolean)
    field(:show, :boolean)
  end

  def initialize({%AdventureMapObject{} = declared, index}) do
    %AdventureMapObject{x: x, y: y, layer_index: layer_index, show: show} = declared

    %__MODULE__{
      index: index,
      name: declared.name,
      layer_index: layer_index,
      x: GeometryMapper.to_subpixels(x),
      y: GeometryMapper.to_subpixels(y),
      locked: true,
      show: show
    }
  end
end
