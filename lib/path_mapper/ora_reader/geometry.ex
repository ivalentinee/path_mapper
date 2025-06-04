defmodule PathMapper.ORAReader.Geometry do
  alias PathMapper.ORAReader.XML

  def get_dimensions(element) do
    with {:ok, width_string} <- XML.get_attribute_value(element, :w),
         {width, _} <- Integer.parse(width_string),
         {:ok, height_string} <- XML.get_attribute_value(element, :h),
         {height, _} <- Integer.parse(height_string) do
      {:ok, {width, height}}
    else
      _error -> {:error, "Failed to get ORA element geometry"}
    end
  end

  def get_position(element) do
    with {:ok, x_string} <- XML.get_attribute_value(element, :x),
         {x, _} <- Integer.parse(x_string),
         {:ok, y_string} <- XML.get_attribute_value(element, :y),
         {y, _} <- Integer.parse(y_string) do
      {:ok, {x, y}}
    else
      _error -> {:error, "Failed to get ORA element geometry"}
    end
  end
end
