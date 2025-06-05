defmodule PathMapperWeb.MasterLive.AdventureSelectorComponent do
  use PathMapperWeb, :live_component

  alias PathMapper.Adventures

  def handle_event("select_adventure", %{"name" => name}, socket) do
    Adventures.load_adventure(name)
    {:noreply, socket}
  end

  def select_button_extra_classes(adventure_filename, loaded_adventure) do
    if loaded_adventure && adventure_filename == loaded_adventure.file, do: "selected", else: ""
  end
end
