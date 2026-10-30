defmodule PathMapperWeb.Scene.RightPanelTest do
  use PathMapperWeb.ConnCase
  import Phoenix.LiveViewTest

  alias PathMapper.Session.Resolve

  describe "GM view" do
    setup %{conn: conn} do
      load_session()
      load_party()

      conn = get(conn, "/master")
      assert html_response(conn, 200)
      {:ok, view, html} = live(conn)

      {:ok, %{view: view, html: html}}
    end

    test "group button toggles panel open/closed", %{view: view} do
      assert !find_html_element(render(view), ".group-overview")

      view |> element(".right-panel-button", "Characters") |> render_click()
      assert find_html_element(render(view), ".group-overview")

      view |> element(".right-panel-button", "Characters") |> render_click()
      assert !find_html_element(render(view), ".group-overview")
    end

    test "group panel shows character entries", %{view: view} do
      view |> element(".right-panel-button", "Characters") |> render_click()
      html = render(view)

      assert find_html_element(html, ".group-character")
      assert find_html_element(html, ".group-character-name")
      assert find_html_element(html, ".group-character-player")
    end

    test "character with class shows class", %{view: view} do
      view |> element(".right-panel-button", "Characters") |> render_click()
      html = render(view)

      assert find_html_element(html, ".group-character-class")
    end

    test "snap-to-grid toggles", %{view: view} do
      view |> element("#snap-to-grid") |> render_click()
      view |> element("#snap-to-grid") |> render_click()
    end
  end

  describe "Player view" do
    setup %{conn: conn} do
      load_session()
      load_party()

      conn = get(conn, "/")
      assert html_response(conn, 200)
      {:ok, view, html} = live(conn)

      {:ok, %{view: view, html: html}}
    end

    test "right panel renders on player view", %{html: html} do
      assert find_html_element(html, ".right-panel")
    end

    test "group panel works on player view", %{view: view} do
      view |> element(".right-panel-button", "Characters") |> render_click()
      assert find_html_element(render(view), ".group-overview")
    end

    # The claim used to send the character name while the lookup matched on id, so
    # it found nobody and did nothing at all - silently, since a claim that fails
    # just leaves the button where it was.
    test "claiming a character marks that player as mine", %{view: view} do
      player = hd(Resolve.characters())

      view |> element(".right-panel-button", "Characters") |> render_click()
      view |> element(~s{button[phx-value-id="#{player.id}"]}) |> render_click()
      html = render(view)

      assert find_html_element(html, ".group-character.claimed")
      refute find_html_element(html, "button.claim-character-button")
    end

    test "claiming sends the player id, not the character name", %{view: view} do
      player = hd(Resolve.characters())

      view |> element(".right-panel-button", "Characters") |> render_click()
      buttons = Floki.find(Floki.parse_document!(render(view)), "button.claim-character-button")

      assert Floki.attribute(buttons, "phx-value-id") == Enum.map(Resolve.characters(), & &1.id)
      refute player.id == player.character_name
    end

    # Same defect as the claim: the buttons sent the character name while the
    # action resolved a player by id, so nothing was ever found and nothing added.
    test "adding my token to the map puts it on the scene", %{view: view} do
      claim(view)

      view |> element("button", "Add to map") |> render_click()

      assert my_token_ids() == [claimed_character().token_id]
    end

    test "adding an extra token puts that extra on the scene", %{view: view} do
      claim(view)
      extra = hd(claimed_character().extra_token_ids)

      view |> element(~s{.character-menu-extra-add[phx-value-index="0"]}) |> render_click()

      assert extra in Enum.map(scene_tokens(), & &1.data.id)
    end

    test "the add buttons address the player by id, not by character name", %{view: view} do
      claim(view)
      html = render(view)

      assert Floki.attribute(
               find_html_element(html, "button.character-menu-button"),
               "phx-value-id"
             ) ==
               [claimed_character().id]

      extras = Floki.find(Floki.parse_document!(html), ".character-menu-extra-add")

      assert Floki.attribute(extras, "phx-value-id") ==
               Enum.map(claimed_character().extra_token_ids, fn _ -> claimed_character().id end)
    end

    test "removing my token takes it off the scene again", %{view: view} do
      claim(view)
      view |> element("button", "Add to map") |> render_click()
      assert my_token_ids() == [claimed_character().token_id]

      view |> element("button", "Remove from map") |> render_click()

      assert my_token_ids() == []
    end

    test "claiming one character leaves the others claimable", %{view: view} do
      view |> element(".right-panel-button", "Characters") |> render_click()
      view |> element(~s{button[phx-value-id="#{hd(Resolve.characters()).id}"]}) |> render_click()
      html = render(view)

      assert length(Floki.find(Floki.parse_document!(html), ".group-character")) ==
               length(Resolve.characters())

      assert length(Floki.find(Floki.parse_document!(html), ".group-character.claimed")) == 1
    end

    defp claimed_character, do: hd(Resolve.characters())

    # The add and remove buttons are disabled without an active scene, since there
    # is nowhere to put a token.
    defp claim(view) do
      select_surface()
      view |> element(".right-panel-button", "Characters") |> render_click()
      view |> element(~s{button[phx-value-id="#{claimed_character().id}"]}) |> render_click()
      view |> element(".right-panel-button", "Mine") |> render_click()
    end

    defp scene_tokens do
      case PathMapper.Game.get_state() do
        %{surface: %{tokens: tokens}} when is_list(tokens) -> tokens
        _ -> []
      end
    end

    defp my_token_ids do
      scene_tokens()
      |> Enum.filter(&(&1.data.owner == claimed_character().id))
      |> Enum.map(& &1.data.id)
    end
  end

  describe "a session with nobody in it" do
    setup %{conn: conn} do
      conn = get(conn, "/master")
      assert html_response(conn, 200)
      {:ok, view, html} = live(conn)

      {:ok, %{view: view, html: html}}
    end

    test "the characters button is hidden where there are no characters", %{html: html} do
      refute html =~ "toggle_group_panel"
    end
  end
end
