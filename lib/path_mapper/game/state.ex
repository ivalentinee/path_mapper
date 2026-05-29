defmodule PathMapper.Game.State do
  use Ecto.Schema

  @primary_key false

  embedded_schema do
    field(:active_scene, :integer)
    field(:scenes, :map, default: %{})
    field(:initiative, {:array, :map}, default: [])
  end

  def scene(%__MODULE__{active_scene: nil}), do: nil

  def scene(%__MODULE__{active_scene: index, scenes: scenes}) do
    Map.get(scenes, index)
  end

  def put_scene(%__MODULE__{active_scene: nil}, _scene) do
    raise "put_scene called with no active scene"
  end

  def put_scene(%__MODULE__{active_scene: index} = state, %__MODULE__.Scene{} = scene)
      when is_integer(index) do
    Map.update!(state, :scenes, &Map.put(&1, index, scene))
  end
end
