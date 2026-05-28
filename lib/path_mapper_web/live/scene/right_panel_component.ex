defmodule PathMapperWeb.Scene.RightPanelComponent do
  use PathMapperWeb, :live_component

  embed_templates "right_panel/*"

  @impl true
  def handle_event("toggle_group_panel", _, socket) do
    send(self(), %{right_panel_update: :toggle_group_panel})
    {:noreply, socket}
  end

  @impl true
  def handle_event("toggle_links_panel", _, socket) do
    send(self(), %{right_panel_update: :toggle_links_panel})
    {:noreply, socket}
  end

  @impl true
  def handle_event("snap_to_grid", _, socket) do
    send(self(), %{scene_update: :snap_to_grid})
    {:noreply, socket}
  end

  @impl true
  def handle_event("noop", _, socket), do: {:noreply, socket}
end
