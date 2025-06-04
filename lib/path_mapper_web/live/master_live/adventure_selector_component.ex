defmodule PathMapperWeb.MasterLive.AdventureSelectorComponent do
  use PathMapperWeb, :live_component

  alias PathMapper.Adventures

  def handle_event("select_adventure", %{"name" => name}, socket) do
    Adventures.load_adventure(name)
    {:noreply, socket}
  end

  def select_button_extra_classes(file, loaded_adventure) do
    if is_a_selected_adventure(file, loaded_adventure), do: "selected", else: ""
  end

  def is_a_selected_adventure(file, loaded_adventure) do
    loaded_adventure && file == loaded_adventure.file
  end
end
