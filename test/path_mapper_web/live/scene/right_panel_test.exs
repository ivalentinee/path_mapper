defmodule PathMapperWeb.Scene.RightPanelTest do
  use PathMapperWeb.ConnCase
  import Phoenix.LiveViewTest

  alias PathMapper.Groups

  describe "GM view" do
    setup %{conn: conn} do
      load_adventure("tt0001-0000000001-adventure-1.zip")
      {:ok, _group} = load_group("tg0001-0000000001-group-1.zip")

      conn = get(conn, "/master")
      assert html_response(conn, 200)
      {:ok, view, html} = live(conn)

      {:ok, %{view: view, html: html}}
    end

    test "right panel renders with Group, Links, and snap-to-grid buttons", %{html: html} do
      assert find_html_element(html, ".right-panel")
      assert find_html_element(html, "#snap-to-grid")
      assert html =~ "Group"
      assert html =~ "Links"
    end

    test "group button toggles panel open/closed", %{view: view} do
      assert !find_html_element(render(view), ".group-overview")

      view |> element(".right-panel-button", "Group") |> render_click()
      assert find_html_element(render(view), ".group-overview")

      view |> element(".right-panel-button", "Group") |> render_click()
      assert !find_html_element(render(view), ".group-overview")
    end

    test "group panel shows character entries", %{view: view} do
      view |> element(".right-panel-button", "Group") |> render_click()
      html = render(view)

      assert find_html_element(html, ".group-character")
      assert find_html_element(html, ".group-character-name")
      assert find_html_element(html, ".group-character-player")
    end

    test "character with class shows class", %{view: view} do
      view |> element(".right-panel-button", "Group") |> render_click()
      html = render(view)

      assert find_html_element(html, ".group-character-class")
    end

    test "group title is displayed", %{view: view} do
      view |> element(".right-panel-button", "Group") |> render_click()
      html = render(view)

      assert find_html_element(html, ".group-title")
    end

    test "snap-to-grid toggles", %{view: view} do
      view |> element("#snap-to-grid") |> render_click()
      view |> element("#snap-to-grid") |> render_click()
    end

    test "links button toggles panel open/closed", %{view: view} do
      assert !find_html_element(render(view), ".links-panel")

      view |> element(".right-panel-button", "Links") |> render_click()
      assert find_html_element(render(view), ".links-panel")

      view |> element(".right-panel-button", "Links") |> render_click()
      assert !find_html_element(render(view), ".links-panel")
    end

    test "links panel shows URL entries", %{view: view} do
      view |> element(".right-panel-button", "Links") |> render_click()
      html = render(view)

      assert find_html_element(html, ".links-entry")
      assert find_html_element(html, ".links-title")
    end

    test "links are anchor tags with href and target", %{view: view} do
      view |> element(".right-panel-button", "Links") |> render_click()
      html = render(view)

      assert html =~ "href=\"https://example.net/\""
      assert html =~ "target=\"_blank\""
      assert html =~ "rel=\"noopener noreferrer\""
    end

    test "mutual exclusion: opening Links closes Group", %{view: view} do
      view |> element(".right-panel-button", "Group") |> render_click()
      assert find_html_element(render(view), ".group-overview")

      view |> element(".right-panel-button", "Links") |> render_click()
      html = render(view)
      assert !find_html_element(html, ".group-overview")
      assert find_html_element(html, ".links-panel")
    end

    test "mutual exclusion: opening Group closes Links", %{view: view} do
      view |> element(".right-panel-button", "Links") |> render_click()
      assert find_html_element(render(view), ".links-panel")

      view |> element(".right-panel-button", "Group") |> render_click()
      html = render(view)
      assert !find_html_element(html, ".links-panel")
      assert find_html_element(html, ".group-overview")
    end
  end

  describe "Player view" do
    setup %{conn: conn} do
      load_adventure("tt0001-0000000001-adventure-1.zip")
      {:ok, _group} = load_group("tg0001-0000000001-group-1.zip")

      conn = get(conn, "/")
      assert html_response(conn, 200)
      {:ok, view, html} = live(conn)

      {:ok, %{view: view, html: html}}
    end

    test "right panel renders on player view", %{html: html} do
      assert find_html_element(html, ".right-panel")
    end

    test "group panel works on player view", %{view: view} do
      view |> element(".right-panel-button", "Group") |> render_click()
      assert find_html_element(render(view), ".group-overview")
    end

    test "links panel works on player view", %{view: view} do
      view |> element(".right-panel-button", "Links") |> render_click()
      assert find_html_element(render(view), ".links-panel")
    end

    test "click outside closes right panel on player view", %{view: view} do
      view |> element(".right-panel-button", "Links") |> render_click()
      assert find_html_element(render(view), ".links-panel")

      view |> element(".player-container") |> render_click()
      assert !find_html_element(render(view), ".links-panel")
    end

    # The claim used to send the character name while the lookup matched on id, so
    # it found nobody and did nothing at all - silently, since a claim that fails
    # just leaves the button where it was.
    test "claiming a character marks that player as mine", %{view: view} do
      {:ok, group} = Groups.get_loaded()
      player = hd(group.players)

      view |> element(".right-panel-button", "Group") |> render_click()
      view |> element(~s{button[phx-value-id="#{player.id}"]}) |> render_click()
      html = render(view)

      assert find_html_element(html, ".group-character.claimed")
      refute find_html_element(html, "button.claim-character-button")
    end

    test "claiming sends the player id, not the character name", %{view: view} do
      {:ok, group} = Groups.get_loaded()
      player = hd(group.players)

      view |> element(".right-panel-button", "Group") |> render_click()
      buttons = Floki.find(Floki.parse_document!(render(view)), "button.claim-character-button")

      assert Floki.attribute(buttons, "phx-value-id") == Enum.map(group.players, & &1.id)
      refute player.id == player.character_name
    end

    # Same defect as the claim: the buttons sent the character name while the
    # action resolved a player by id, so nothing was ever found and nothing added.
    test "adding my token to the map puts it on the scene", %{view: view} do
      claim(view)

      view |> element("button", "Add to map") |> render_click()

      assert my_token_ids() == [player().token_id]
    end

    test "adding an extra token puts that extra on the scene", %{view: view} do
      claim(view)
      extra = hd(player().extra_tokens)

      view |> element(~s{.character-menu-extra-add[phx-value-index="0"]}) |> render_click()

      assert extra.id in Enum.map(scene_tokens(), & &1.data.id)
    end

    test "the add buttons address the player by id, not by character name", %{view: view} do
      claim(view)
      html = render(view)

      assert Floki.attribute(
               find_html_element(html, "button.character-menu-button"),
               "phx-value-id"
             ) ==
               [player().id]

      extras = Floki.find(Floki.parse_document!(html), ".character-menu-extra-add")

      assert Floki.attribute(extras, "phx-value-id") ==
               Enum.map(player().extra_tokens, fn _ -> player().id end)
    end

    test "removing my token takes it off the scene again", %{view: view} do
      claim(view)
      view |> element("button", "Add to map") |> render_click()
      assert my_token_ids() == [player().token_id]

      view |> element("button", "Remove from map") |> render_click()

      assert my_token_ids() == []
    end

    test "claiming one character leaves the others claimable", %{view: view} do
      {:ok, group} = Groups.get_loaded()

      view |> element(".right-panel-button", "Group") |> render_click()
      view |> element(~s{button[phx-value-id="#{hd(group.players).id}"]}) |> render_click()
      html = render(view)

      assert length(Floki.find(Floki.parse_document!(html), ".group-character")) ==
               length(group.players)

      assert length(Floki.find(Floki.parse_document!(html), ".group-character.claimed")) == 1
    end

    defp player do
      {:ok, group} = Groups.get_loaded()
      hd(group.players)
    end

    # The add and remove buttons are disabled without an active scene, since there
    # is nowhere to put a token.
    defp claim(view) do
      select_scene()
      view |> element(".right-panel-button", "Group") |> render_click()
      view |> element(~s{button[phx-value-id="#{player().id}"]}) |> render_click()
      view |> element(".right-panel-button", "Character") |> render_click()
    end

    defp scene_tokens do
      case PathMapper.Game.get_state() do
        %{scene: %{tokens: tokens}} when is_list(tokens) -> tokens
        _ -> []
      end
    end

    defp my_token_ids do
      scene_tokens()
      |> Enum.filter(&(&1.data.owner == player().id))
      |> Enum.map(& &1.data.id)
    end
  end

  describe "no adventure/group loaded" do
    setup %{conn: conn} do
      :persistent_term.erase(PathMapper.Adventures.Adventure)
      :persistent_term.erase(PathMapper.Groups.Group)

      conn = get(conn, "/master")
      assert html_response(conn, 200)
      {:ok, view, html} = live(conn)

      {:ok, %{view: view, html: html}}
    end

    test "links button hidden when no adventure loaded", %{html: html} do
      refute html =~ "toggle_links_panel"
    end

    test "group button hidden when no group loaded", %{html: html} do
      refute html =~ "toggle_group_panel"
    end
  end

  describe "empty URLs" do
    setup %{conn: conn} do
      load_adventure("tt0001-0000000002-adventure-2.zip")

      conn = get(conn, "/master")
      assert html_response(conn, 200)
      {:ok, view, html} = live(conn)

      {:ok, %{view: view, html: html}}
    end

    test "links panel with no URLs shows empty message", %{view: view} do
      view |> element(".right-panel-button", "Links") |> render_click()
      html = render(view)

      assert find_html_element(html, ".panel-empty")
      assert html =~ "No links in this adventure"
    end
  end
end
