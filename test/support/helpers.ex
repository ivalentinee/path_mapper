defmodule PathMapperWeb.TestHelpers do
  alias PathMapper.Game
  alias PathMapper.Groups
  alias PathMapper.Session.Entity
  alias PathMapper.Session.Store
  alias PathMapper.TestClient

  @adventures "test/data/adventures"
  @groups "test/data/groups"

  def find_html_element(html, selector) when is_binary(html) and is_binary(selector) do
    {:ok, document} = Floki.parse_document(html)
    found_elements = Floki.find(document, selector)
    List.first(found_elements)
  end

  def load_adventure(filename) do
    @adventures |> Path.join(filename) |> TestClient.adventure_commands() |> apply_commands()
    :ok
  end

  @doc """
  Sends a command sequence the way the client will.

  Each entity is built and stored exactly as the route does, so a test that
  hydrates a session exercises the path a real one does.
  """
  def apply_commands(commands) do
    Enum.each(commands, fn %{"kind" => kind} = params ->
      {:ok, entity} = Entity.build(kind, Elixir.Map.delete(params, "kind"))
      {:ok, _stored} = Store.put(entity)
    end)

    Game.reconcile()
  end

  @doc """
  Selects a scene by its access index, the way a keystroke does.

  Tests used to pass a position straight to the action because state was keyed by
  one. It is keyed by id now, and the position is a derivation - so this resolves
  it the same way the UI does.
  """
  def select_scene(position \\ 1) do
    Game.run_action([:scene, :select], Game.scene_id_at(position))
  end

  def load_group(filename) do
    @groups |> Path.join(filename) |> TestClient.group_commands() |> apply_commands()
    Groups.get_loaded()
  end
end
