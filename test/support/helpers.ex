defmodule PathMapperWeb.TestHelpers do
  alias PathMapper.Game
  alias PathMapper.Session.Entity
  alias PathMapper.Session.Store
  alias PathMapper.TestClient

  # Four fields and no bytes, which is why a character is the one piece that is
  # not a file. The group package carried these in a manifest; the manifest is
  # gone and nothing else reads that format, so the party lives here where it
  # can be read beside the tests that use it.
  @party [
    %{
      "kind" => "character",
      "id" => "pg0001-0000000001",
      "character_name" => "Character 1",
      "player_name" => "Player 1",
      "color" => "#328546",
      "class" => "Fighter",
      "token_id" => "tk0002-0000000004",
      "extra_token_ids" => ["tk0002-0000000001", "tk0002-0000000002"]
    },
    %{
      "kind" => "character",
      "id" => "pg0001-0000000002",
      "character_name" => "Character 2",
      "player_name" => "Player 2",
      "color" => "#8100fa",
      "class" => nil,
      "token_id" => "tk0002-0000000005",
      "extra_token_ids" => ["tk0002-0000000003"]
    }
  ]

  def find_html_element(html, selector) when is_binary(html) and is_binary(selector) do
    {:ok, document} = Floki.parse_document(html)
    found_elements = Floki.find(document, selector)
    List.first(found_elements)
  end

  @doc """
  Loads a directory of pieces, the way a game master drops files on the client.
  """
  def load_session(name \\ "standard") do
    name |> TestClient.session_commands() |> apply_commands()
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
  Selects a surface by its access index, the way a keystroke does.

  Tests used to pass a position straight to the action because state was keyed
  by one. It is keyed by a map id now, and the position is a derivation - so
  this resolves it the same way the UI does.
  """
  def select_surface(position \\ 1) do
    Game.run_action([:surface, :select], Game.surface_id_at(position))
  end

  @doc """
  Loads the party: its tokens from files, and the characters from `@party`.

  A character's tokens are owned by the character, which is the client's to
  decide - the server composes nothing, so the owner arrives already chosen.
  """
  def load_party do
    apply_commands(Enum.map(TestClient.session_commands("party"), &owned/1) ++ @party)
    PathMapper.Session.Resolve.characters()
  end

  def party, do: @party

  defp owned(%{"id" => id} = token) do
    case Enum.find(@party, &(id in [&1["token_id"] | &1["extra_token_ids"]])) do
      nil -> token
      character -> Elixir.Map.put(token, "owner", character["id"])
    end
  end
end
