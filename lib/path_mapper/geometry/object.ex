defmodule PathMapper.Geometry.Object do
  @enforce_keys [:width, :height, :x, :y]
  defstruct width: 0, height: 0, x: 0, y: 0, scale: 1

  def build(%{width: width, height: height}) do
    %__MODULE__{width: width, height: height, x: 0, y: 0}
  end

  def build(width, height) when is_number(width) and is_number(height) do
    %__MODULE__{width: width, height: height, x: 0, y: 0}
  end

  def move(%__MODULE__{} = object, x, y) when is_number(x) and is_number(y) do
    object
    |> Map.put(:x, x)
    |> Map.put(:y, y)
  end

  def move(%__MODULE__{} = object, %__MODULE__{} = to) do
    object
    |> Map.put(:x, to.x)
    |> Map.put(:y, to.y)
  end
end
