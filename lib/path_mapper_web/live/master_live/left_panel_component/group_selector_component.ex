defmodule PathMapperWeb.MasterLive.LeftPanelComponent.GroupSelectorComponent do
  use PathMapperWeb, :live_component

  alias PathMapper.Groups

  def handle_event("select_group", %{"name" => name}, socket) do
    Groups.load_group(name)
    {:noreply, socket}
  end

  def select_button_extra_classes(group_filename, selected_group) do
    if selected_group && selected_group.file == group_filename,
      do: "selected",
      else: ""
  end
end
