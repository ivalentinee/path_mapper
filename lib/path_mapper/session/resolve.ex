defmodule PathMapper.Session.Resolve do
  @moduledoc """
  Turns what the store holds into what the rest of the code expects.

  The store is normalised - a scene names its map and its tokens - and everything
  downstream of game state reads a scene with those embedded. This is the seam
  between the two, and it exists so that normalising the store did not mean
  rewriting every reader of a scene.

  Overrides are applied here, which is the only place they can be: a token carries
  its defaults, and only the scene using it knows what it wants instead.
  """

  alias PathMapper.Adventures.Adventure
  alias PathMapper.Adventures.Adventure.Scene, as: AdventureScene
  alias PathMapper.Session.Entity
  alias PathMapper.Session.Scene
  alias PathMapper.Session.Store

  @doc "Every scene the store holds, in order."
  def scenes do
    "scene"
    |> Store.of_kind()
    |> Enum.map(& &1.data)
    |> Enum.sort_by(& &1.order)
    |> Enum.map(&scene/1)
  end

  @doc "A scene with its map and tokens in place, or nil."
  def scene(%Scene{} = scene) do
    %AdventureScene{
      id: scene.id,
      ref: scene.ref,
      name: scene.name,
      type: scene.type,
      map: map(scene.map_id),
      tokens: scene.tokens |> Enum.map(&token/1) |> Enum.reject(&is_nil/1),
      place_tokens: scene.place_tokens
    }
  end

  def scene(id) when is_binary(id) do
    case Store.fetch(id, "scene") do
      {:ok, %Entity{data: data}} -> scene(data)
      {:error, _reason} -> nil
    end
  end

  def scene(_other), do: nil

  @doc "The adventure the store holds, with its scenes in place."
  def adventure do
    case Store.of_kind("adventure") do
      [%Entity{data: %Adventure{} = adventure}] -> {:ok, %{adventure | scenes: scenes()}}
      [] -> {:error, "No adventure loaded"}
      _many -> {:error, "More than one adventure is loaded"}
    end
  end

  def group do
    case Store.of_kind("group") do
      [%Entity{data: group}] -> {:ok, group}
      [] -> {:error, "No group loaded"}
      _many -> {:error, "More than one group is loaded"}
    end
  end

  defp map(nil), do: nil

  defp map(id) do
    case Store.fetch(id, "map") do
      {:ok, %Entity{data: data}} -> data
      {:error, _reason} -> nil
    end
  end

  defp token(%Scene.TokenRef{} = ref) do
    case Store.fetch(ref.id, "token") do
      {:ok, %Entity{data: token}} -> override(token, ref)
      {:error, _reason} -> nil
    end
  end

  defp override(token, %Scene.TokenRef{} = ref) do
    %{
      token
      | name: ref.name || token.name,
        owner: ref.owner || token.owner,
        size: ref.size || token.size
    }
  end
end
