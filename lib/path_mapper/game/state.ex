defmodule PathMapper.Game.State do
  @moduledoc """
  What has happened in a session, as distinct from what the session is made of.

  Scenes are keyed by id and `active_scene` holds an id, because a placement has to
  survive leaving a scene and coming back — so it cannot belong to the scene being
  looked at, and it cannot be found by a position that changes when a scene is
  inserted. Nothing here is an access path: where an ordering or a lookup wants to
  be fast, that is a job for data management rather than for this shape.
  """

  use Ecto.Schema

  @primary_key false

  embedded_schema do
    field(:active_scene, :string)
    field(:scenes, :map, default: %{})
    field(:initiative, {:array, :map}, default: [])
  end

  def scene(%__MODULE__{active_scene: nil}), do: nil

  def scene(%__MODULE__{active_scene: id, scenes: scenes}) do
    Map.get(scenes, id)
  end

  def put_scene(%__MODULE__{active_scene: nil}, _scene) do
    raise "put_scene called with no active scene"
  end

  def put_scene(%__MODULE__{active_scene: id} = state, %__MODULE__.Scene{} = scene)
      when is_binary(id) do
    Map.update!(state, :scenes, &Map.put(&1, id, scene))
  end

  @doc "Scenes in the order their declarations gave them."
  def ordered(%__MODULE__{scenes: scenes}) do
    scenes |> Map.values() |> Enum.sort_by(& &1.order)
  end
end
