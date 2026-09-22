defmodule PathMapperWeb.Scene.PlayerOwnTokenTest do
  @moduledoc """
  What a player may do with their own token on the board.

  A placed token's owner is the player's *id*: `Find.player_token/1` sets it, and
  `Palette.build/1` keys colours by it. The player view passed a character name
  instead, so every one of these comparisons matched nothing.
  """
  use PathMapperWeb.ConnCase
  import Phoenix.LiveViewTest

  alias PathMapper.Game
  alias PathMapper.Game.Palette
  alias PathMapper.Groups

  setup %{conn: conn} do
    {:ok, group} = load_group("tg0001-0000000001-group-1.zip")
    load_adventure("tt0001-0000000001-adventure-1.zip")
    :ok = select_scene(1)

    player = hd(group.players)
    :ok = Game.run_action([:tokens, :player, :add], player.id)

    conn = get(conn, "/")
    assert html_response(conn, 200)
    {:ok, view, _html} = live(conn)

    claim(view, player)
    report_viewport(view)

    {:ok, %{view: view, player: player}}
  end

  # The board has no size until the browser reports one, and without a size it
  # renders no tokens at all. Supplied here the way the hook does.
  defp report_viewport(view) do
    view |> element("#scene") |> render_hook("geometry", %{"width" => 1600, "height" => 1000})
  end

  defp claim(view, player) do
    view |> element(".right-panel-button", "Group") |> render_click()
    view |> element(~s{button[phx-value-id="#{player.id}"]}) |> render_click()
  end

  # The palette is keyed by player id, so resolving a character name returned the
  # default and the player drew in black. Asserted on the tool overlay rather than
  # anywhere `player.color` appears, since the group panel renders it regardless.
  test "the player's tools take their own colour, not the palette default",
       %{view: view, player: player} do
    colour =
      render(view)
      |> Floki.parse_document!()
      |> Floki.find("[data-tool-color]")
      |> Floki.attribute("data-tool-color")

    assert colour == [player.color]
  end

  test "a player sees their own token even when it is hidden", %{view: view, player: player} do
    own = Enum.find(Game.get_state().scene.tokens, &(&1.owner == player.id))
    :ok = Game.run_action([:tokens, own.game_id, :set_state], "hidden")

    assert render(view) =~ own.game_id
  end

  # can_manage_token?/1 gates the context menu. Dragging is deliberately ungated -
  # a standing authorization gap recorded as deferred work, not this test's subject.
  test "a player may open the context menu on their own token", %{view: view, player: player} do
    own = Enum.find(Game.get_state().scene.tokens, &(&1.owner == player.id))

    view
    |> element(~s{[data-game-id="#{own.game_id}"]})
    |> render_hook("context_menu", %{"x" => 10, "y" => 10})

    assert find_html_element(render(view), ".token-context-menu")
  end

  test "a player may not open the context menu on a token that is not theirs",
       %{view: view, player: player} do
    other = Enum.find(Game.get_state().scene.tokens, &(&1.owner != player.id))

    view
    |> element(~s{[data-game-id="#{other.game_id}"]})
    |> render_hook("context_menu", %{"x" => 10, "y" => 10})

    refute find_html_element(render(view), ".token-context-menu")
  end

  # Initiative owned by a character name sat outside the palette too, so a
  # player's own line drew in the default colour.
  test "a player's initiative entry is owned by their id, so it takes their colour",
       %{view: view, player: player} do
    view |> element(".right-panel-button", "Initiative") |> render_click()

    view
    |> element("form[phx-submit=\"submit_initiative\"]")
    |> render_submit(%{"value" => "17"})

    entry = Enum.find(Game.get_state().initiative, &(&1.name == player.character_name))

    assert entry.owner == player.id
    assert Palette.resolve(entry.owner) == player.color
  end

  # The draw actions read "GM" as authority - erase anyone's, undo the last
  # regardless of owner, clear the board. Owning drawings by character name meant
  # a player who called their character GM inherited all three.
  #
  # Exercised through the view's undo button, which is what carries the owner the
  # player view believes in. Drawing *creation* takes its owner from the same
  # assign but never renders it, so it is covered at the action level below.
  test "the player view undoes drawings by the player's id", %{view: view, player: player} do
    :ok =
      Game.run_action([:draw, :add], %{
        type: :line,
        color: player.color,
        owner: player.id,
        data: %{"x1" => 0, "y1" => 0, "x2" => 10, "y2" => 10}
      })

    assert length(Game.get_state().scene.drawn_elements) == 1

    view |> element("button.undo-button") |> render_click()

    assert Game.get_state().scene.drawn_elements == []
  end

  # The keystroke path is a second site with its own copy of the owner, in
  # PlayerLive rather than in the panel.
  test "the keyboard undo also names the player by id", %{view: view, player: player} do
    :ok =
      Game.run_action([:draw, :add], %{
        type: :line,
        color: player.color,
        owner: player.id,
        data: %{"x1" => 0, "y1" => 0, "x2" => 10, "y2" => 10}
      })

    send(view.pid, %{session_event: :draw_undo})
    render(view)

    assert Game.get_state().scene.drawn_elements == []
  end

  test "a drawing a player owns is undone by their id", %{player: player} do
    :ok =
      Game.run_action([:draw, :add], %{
        type: :line,
        color: player.color,
        owner: player.id,
        data: %{"x1" => 0, "y1" => 0, "x2" => 10, "y2" => 10}
      })

    assert length(Game.get_state().scene.drawn_elements) == 1

    :ok = Game.run_action([:draw, :undo], %{owner: player.character_name})
    assert length(Game.get_state().scene.drawn_elements) == 1

    :ok = Game.run_action([:draw, :undo], %{owner: player.id})
    assert Game.get_state().scene.drawn_elements == []
  end

  test "the group's own id is what a placed player token carries", %{player: player} do
    {:ok, group} = Groups.get_loaded()

    assert Enum.any?(Game.get_state().scene.tokens, &(&1.owner == player.id))
    refute Enum.any?(Game.get_state().scene.tokens, &(&1.owner == player.character_name))
    assert hd(group.players).id == player.id
  end
end
