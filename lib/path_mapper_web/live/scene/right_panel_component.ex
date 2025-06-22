defmodule PathMapperWeb.Scene.RightPanelComponent do
  use PathMapperWeb, :live_component

  @impl true
  def handle_event("snap_to_grid", _, socket) do
    send(self(), %{scene_update: :snap_to_grid})
    {:noreply, socket}
  end
end
