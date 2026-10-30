defmodule PathMapperWeb.MasterLive.LeftPanelComponent.TokensComponent.Add do
  use PathMapperWeb, :live_component

  require PathMapperWeb.MasterLive.LeftPanelState

  alias PathMapper.Game
  alias PathMapper.Game.Actions.Tokens.Find
  alias PathMapper.Session.Resolve

  @impl true
  def update(assigns, socket) do
    # Collapse the search again when the game master moves to another surface.
    moved? =
      socket.assigns[:surface_id] != nil and socket.assigns[:surface_id] != assigns[:surface_id]

    socket = assign(socket, assigns)

    socket =
      if moved? do
        assign(socket, expanded: false, search: "")
      else
        socket
        |> assign_new(:expanded, fn -> false end)
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

  # Every token the session holds. There is no per-surface roster any more - a
  # surface is a map and holds no list of its own - so the store is the only
  # source, and expanding reveals the search rather than a longer list.
  #
  # Characters' tokens are the exception: they are placed from the Characters and
  # Extras panels, which know that a character goes down once and a marking as
  # often as asked. Offering them here would be a second route that knows
  # neither rule.
  defp visible_tokens(assigns) do
    characters = Find.character_token_ids()

    Resolve.tokens()
    |> Enum.reject(&MapSet.member?(characters, &1.id))
    |> filter_by_name(assigns.search)
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
