defmodule PathMapperWeb.MasterLive.LeftPanelComponent.TokensComponent.Add do
  use PathMapperWeb, :live_component

  require PathMapperWeb.MasterLive.LeftPanelState

  alias PathMapper.Adventures.Adventure
  alias PathMapper.Game
  alias PathMapper.GlobalTokens

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
  def handle_event("add_token", %{"name" => name}, socket) do
    Game.run_action([:tokens, :add], name)
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

  defp visible_tokens(assigns) do
    if assigns.expanded do
      adventure_tokens =
        case assigns[:adventure] do
          %Adventure{} = adv -> Adventure.all_tokens(adv)
          _ -> []
        end

      global_entries = GlobalTokens.get()
      global_tokens = Enum.map(global_entries, & &1.token)

      # Adventure tokens win on name collision
      adventure_names = MapSet.new(adventure_tokens, & &1.name)
      unique_globals = Enum.reject(global_tokens, &MapSet.member?(adventure_names, &1.name))

      all = (adventure_tokens ++ unique_globals) |> Enum.sort_by(& &1.name)

      case String.trim(assigns.search || "") do
        "" -> all
        query -> filter_with_metadata(all, global_entries, query)
      end
    else
      assigns.tokens
    end
  end

  defp filter_with_metadata(tokens, global_entries, query) do
    q = String.downcase(query)
    global_index = Map.new(global_entries, fn e -> {e.token.name, e} end)
    Enum.filter(tokens, &token_matches?(&1, global_index, q))
  end

  defp token_matches?(token, global_index, query) do
    String.contains?(String.downcase(token.name), query) ||
      metadata_matches?(global_index[token.name], query)
  end

  defp metadata_matches?(%GlobalTokens.Entry{group: group, tags: tags}, query) do
    (group && String.contains?(String.downcase(group), query)) ||
      Enum.any?(tags || [], &String.contains?(String.downcase(&1), query))
  end

  defp metadata_matches?(_, _), do: false
end
