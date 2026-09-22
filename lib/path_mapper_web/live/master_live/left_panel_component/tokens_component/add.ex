defmodule PathMapperWeb.MasterLive.LeftPanelComponent.TokensComponent.Add do
  use PathMapperWeb, :live_component

  require PathMapperWeb.MasterLive.LeftPanelState

  alias PathMapper.Game
  alias PathMapper.Groups
  alias PathMapper.Session.Resolve

  @impl true
  def update(assigns, socket) do
    # Reset expanded on scene change
    old_scene_index = socket.assigns[:scene_index]
    new_scene_index = assigns[:scene_index]
    scene_changed = old_scene_index != nil and old_scene_index != new_scene_index

    socket = assign(socket, assigns)

    socket =
      if scene_changed do
        assign(socket, expanded: assigns[:is_custom] || false, search: "")
      else
        socket
        |> assign_new(:expanded, fn -> assigns[:is_custom] || false end)
        |> assign_new(:search, fn -> "" end)
      end

    {:ok, assign(socket, :visible_tokens, visible_tokens(socket.assigns))}
  end

  @impl true
  def handle_event("add_token", %{"id" => id}, socket) do
    Game.run_action([:tokens, :add], id)
    {:noreply, socket}
  end

  @impl true
  def handle_event("toggle_expanded", _, socket) do
    expanded = !socket.assigns.expanded
    socket = assign(socket, expanded: expanded, search: "")
    {:noreply, assign(socket, :visible_tokens, visible_tokens(socket.assigns))}
  end

  @impl true
  def handle_event("search", %{"search" => query}, socket) do
    socket = assign(socket, :search, query)
    {:noreply, assign(socket, :visible_tokens, visible_tokens(socket.assigns))}
  end

  # Collapsed shows the scene's own roster; expanded shows everything the session
  # holds. That is the store rather than the union of scene rosters, so a token
  # uploaded on its own - which no scene names - can still be placed.
  #
  # Players' tokens are the exception: they are placed from the Players and Extras
  # panels, which know that a character goes down once and a marking as often as
  # asked. Offering them here would be a second route that knows neither rule.
  defp visible_tokens(assigns) do
    if assigns.expanded do
      players = Groups.player_token_ids()

      Resolve.tokens()
      |> Enum.reject(&MapSet.member?(players, &1.id))
      |> filter_by_name(assigns.search)
    else
      assigns.tokens
    end
  end

  defp filter_by_name(tokens, search) do
    case String.trim(search || "") do
      "" ->
        tokens

      query ->
        q = String.downcase(query)
        Enum.filter(tokens, &String.contains?(String.downcase(&1.name), q))
    end
  end
end
