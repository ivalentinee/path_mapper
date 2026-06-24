defmodule PathMapperWeb.MasterLive.LeftPanelComponent.TokensComponent.Add do
  use PathMapperWeb, :live_component

  require PathMapperWeb.MasterLive.LeftPanelState

  alias PathMapper.Adventures.Adventure
  alias PathMapper.Game

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
    tokens =
      if assigns.expanded do
        case assigns[:adventure] do
          %Adventure{} = adv -> Adventure.all_tokens(adv)
          _ -> assigns.tokens
        end
      else
        assigns.tokens
      end

    case String.trim(assigns.search || "") do
      "" -> tokens
      query -> Enum.filter(tokens, &matches?(&1.name, query))
    end
  end

  defp matches?(name, query) do
    String.contains?(String.downcase(name), String.downcase(query))
  end
end
