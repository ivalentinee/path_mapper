defmodule PathMapper.Geometry.Mapper do
  alias PathMapper.Geometry.Object

  @doc "Returns the subpixel factor used for internal coordinate precision."
  def subpixel_factor, do: Application.get_env(:path_mapper, :subpixel_factor)

  @doc "Convert a map-unit value to subpixel units."
  def to_subpixels(value) when is_number(value), do: round(value * subpixel_factor())

  @doc "Convert a subpixel value back to map units."
  def from_subpixels(value) when is_number(value), do: value / subpixel_factor()

  @doc """
  Convert a coordinate value to internal subpixel units, accounting for the
  source precision declared by an optional `subpixel` field.

  - `nil` source precision: value is in map units, multiply by factor.
  - Source precision matches internal factor: use as-is.
  - Different source precision: rescale to internal factor.
  """
  def coordinate_to_subpixels(value, nil) when is_number(value),
    do: to_subpixels(value)

  def coordinate_to_subpixels(value, source_factor)
      when is_number(value) and is_integer(source_factor) do
    factor = subpixel_factor()

    if source_factor == factor do
      value
    else
      round(value * factor / source_factor)
    end
  end

  @doc """
  Center an object within a viewport by setting its x/y to equal padding on each side.
  """
  def center(%Object{} = object, %Object{} = viewport) do
    x_padding = floor((viewport.width - object.width) / 2)
    y_padding = floor((viewport.height - object.height) / 2)

    object
    |> Map.put(:x, x_padding)
    |> Map.put(:y, y_padding)
  end

  @doc """
  Scale an object to fit within a viewport, preserving aspect ratio.

  Uses the dominant axis (wider or taller relative to viewport) to compute
  the scale factor. Stores the scale on the object for use by `scale_to/2`
  and `scale_back/2`.
  """
  def fit_to_viewport(%Object{} = object, %Object{} = viewport) do
    scale = calculate_scale(object, viewport)

    object
    |> Map.put(:scale, scale)
    |> Map.put(:width, object.width / scale)
    |> Map.put(:height, object.height / scale)
  end

  @doc """
  Convert subpixel coordinates to screen-pixel coordinates relative to the map origin.
  """
  def scale_to(%Object{} = object, %Object{} = map_geometry) do
    object
    |> Map.put(:width, scale_to(object.width, map_geometry))
    |> Map.put(:height, scale_to(object.height, map_geometry))
    |> Map.put(:x, scale_to(object.x, map_geometry))
    |> Map.put(:y, scale_to(object.y, map_geometry))
  end

  def scale_to(coordinate, %Object{scale: scale}) when is_number(coordinate) do
    round(coordinate / (scale * subpixel_factor()))
  end

  @doc "Convert a single screen-pixel value back to subpixel coordinates."
  def scale_back(coordinate, %Object{scale: scale}) when is_number(coordinate) do
    round(coordinate * scale * subpixel_factor())
  end

  @doc """
  Convert a viewport-pixel position to subpixel map coordinates.

  Accounts for the map's centering offset (map_geometry.x/y) and scale.
  Use this for translating mouse/drag events (which report viewport clientX/Y)
  into the map's coordinate system.
  """
  def viewport_to_map(viewport_x, viewport_y, %Object{} = map_geometry) do
    map_relative_x = viewport_x - map_geometry.x
    map_relative_y = viewport_y - map_geometry.y

    {scale_back(map_relative_x, map_geometry), scale_back(map_relative_y, map_geometry)}
  end

  @doc """
  Convert a map-relative screen position to a viewport-pixel position.

  Inverse of removing the map offset: adds the centering offset back.
  Use this for computing viewport-relative positions from map-relative ones.
  """
  def map_screen_to_viewport(screen_x, screen_y, %Object{} = map_geometry) do
    {screen_x + map_geometry.x, screen_y + map_geometry.y}
  end

  @doc """
  Convert a map-pixel value to screen pixels.

  For static adventure-schema coordinates (layer x/y/width/height) that are
  in plain map pixels, not subpixels. Divides by scale only (no subpixel factor).
  """
  def scale_map_pixel(value, %Object{scale: scale}) when is_number(value) do
    round(value / scale)
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
