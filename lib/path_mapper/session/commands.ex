defmodule PathMapper.Session.Commands do
  @moduledoc """
  The commands that change what a session is made of.

  Everything that adds, removes or replaces an entity comes through here, whoever
  asked - the API, or the console until it stops composing. Game state changes go
  elsewhere, through `PathMapper.Game.run_action/2`, and the two do not overlap.
  """

  alias PathMapper.Adventures.Adventure.Scene.Map, as: SceneMap
  alias PathMapper.Game
  alias PathMapper.Id
  alias PathMapper.Session.Entity
  alias PathMapper.Session.Scene
  alias PathMapper.Session.Store

  @adhoc_series "sc9999"

  def put(%Entity{} = entity) do
    with {:ok, stored} <- Store.put(entity) do
      Game.reconcile()
      {:ok, stored}
    end
  end

  def remove(id) when is_binary(id) do
    :ok = Store.delete(id)
    Game.reconcile()
    :ok
  end

  @doc """
  Declares a scene made at the table.

  Its id continues the series the session is already using, so it reads and sorts
  with the rest: the entity part of the highest scene id, incremented.
  """
  def create_scene(name) when is_binary(name) do
    trimmed = name |> String.trim() |> String.slice(0, 50)

    cond do
      trimmed == "" -> {:error, "Scene name cannot be empty"}
      name_taken?(trimmed) -> {:error, "Scene name already exists"}
      true -> put(scene_entity(trimmed))
    end
  end

  defp scene_entity(name) do
    id = next_scene_id()

    %Entity{
      id: id,
      kind: "scene",
      data: %Scene{
        id: id,
        name: name,
        order: next_order(),
        map_id: nil,
        tokens: [],
        place_tokens: []
      }
    }
  end

  defp existing_scenes, do: "scene" |> Store.of_kind() |> Enum.map(& &1.data)

  defp next_scene_id, do: next_scene_id_of(existing_scenes())

  defp next_scene_id_of([]), do: Id.generate(@adhoc_series)

  defp next_scene_id_of(scenes) do
    scenes |> Enum.map(& &1.id) |> Enum.max() |> increment()
  end

  # Ordinary carry: the entity part is incremented and re-padded to its width.
  defp increment(id) do
    [series, entity] = String.split(id, "-", parts: 2)
    width = String.length(entity)
    next = entity |> String.to_integer() |> Kernel.+(1)
    "#{series}-#{next |> to_string() |> String.pad_leading(width, "0")}"
  end

  defp next_order do
    case existing_scenes() do
      [] -> 0
      scenes -> (scenes |> Enum.map(&(&1.order || 0)) |> Enum.max()) + 1
    end
  end

  defp name_taken?(name), do: Enum.any?(existing_scenes(), &(&1.name == name))

  @doc """
  Adds a token to the tokens a scene uses.

  Placing a token is a play action and needs the scene to list it first: a scene
  holding something it does not list would be holding something it does not know
  about.
  """
  def bind_token(scene_id, token_id, overrides \\ %{}) do
    with {:ok, %Entity{data: scene}} <- Store.fetch(scene_id, "scene"),
         {:ok, _token} <- Store.fetch(token_id, "token") do
      ref = struct(Scene.TokenRef, Elixir.Map.put(overrides, :id, token_id))
      tokens = Enum.reject(scene.tokens, &(&1.id == token_id)) ++ [ref]

      put(%Entity{id: scene_id, kind: "scene", data: %{scene | tokens: tokens}})
    end
  end

  @doc "Puts a map's bytes behind a scene."
  def bind_map(scene_id, %SceneMap{} = map) do
    with {:ok, %Entity{data: scene}} <- Store.fetch(scene_id, "scene"),
         {:ok, _map} <- Store.put(%Entity{id: map.id, kind: "map", data: map}),
         {:ok, stored} <-
           Store.put(%Entity{id: scene_id, kind: "scene", data: %{scene | map_id: map.id}}) do
      Game.reconcile()
      {:ok, stored}
    end
  end
end
