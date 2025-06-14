defmodule PathMapper.Geometry.Mapper do
  alias PathMapper.Geometry.Object

  def center(%Object{} = object, %Object{} = viewport) do
    x_padding = floor((viewport.width - object.width) / 2)
    y_padding = floor((viewport.height - object.height) / 2)

    object
    |> Map.put(:x, x_padding)
    |> Map.put(:y, y_padding)
  end

  def fit_to_viewport(%Object{} = object, %Object{} = viewport) do
    scale = calculate_scale(object, viewport)

    object
    |> Map.put(:scale, scale)
    |> Map.put(:width, object.width / scale)
    |> Map.put(:height, object.height / scale)
  end

  def scale_to(%Object{} = object, %Object{} = target) do
    object
    |> Map.put(:width, scale_to(object.width, target))
    |> Map.put(:height, scale_to(object.height, target))
    |> Map.put(:x, scale_to(object.x, target))
    |> Map.put(:y, scale_to(object.y, target))
  end

  def scale_to(coordinate, %Object{scale: scale} = _target) when is_number(coordinate) do
    round(coordinate / scale)
  end

  def scale_back(coordinate, %Object{scale: scale} = _target) when is_number(coordinate) do
    round(coordinate * scale)
  end

  defp calculate_scale(%Object{} = object, %Object{} = viewport) do
    object_width_to_height_relation = object.width / object.height
    viewport_width_to_height_relation = viewport.width / viewport.height

    if object_width_to_height_relation > viewport_width_to_height_relation do
      object.width / viewport.width
    else
      object.height / viewport.height
    end
  end
end
