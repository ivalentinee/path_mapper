defmodule PathMapperWeb.MasterLive.LeftPanelComponent.AdventureSelectorComponent do
  use PathMapperWeb, :live_component

  alias PathMapper.Adventures
  alias PathMapper.Game

  @impl true
  def handle_event("select_adventure", %{"name" => name}, socket) do
    Game.load(name)
    {:noreply, socket}
  end

  @impl true
  def handle_event("start_empty", _, socket) do
    Game.reset_empty()
    {:noreply, socket}
  end

  @impl true
  def handle_event("reload", _, socket) do
    Adventures.reload()
    PathMapper.GlobalTokens.reload()
    {:noreply, socket}
  end

  @impl true
  def handle_event("dump_state", _, socket) do
    case Game.dump_state() do
      {:ok, data} ->
        json = Jason.encode!(data, pretty: true)
        timestamp = Calendar.strftime(DateTime.utc_now(), "%Y-%m-%d-%H-%M")
        adventure_name = Path.rootname(socket.assigns.adventure.file)
        filename = "#{adventure_name}-state-#{timestamp}.json"
        {:noreply, push_event(socket, "download", %{data: json, filename: filename})}

      {:error, reason} ->
        {:noreply, put_flash(socket, :error, reason)}
    end
  end

  @impl true
  def handle_event("reset_all", _, socket) do
    if socket.assigns[:confirm_reset] do
      Game.clear()
      {:noreply, assign(socket, :confirm_reset, false)}
    else
      {:noreply, assign(socket, :confirm_reset, true)}
    end
  end

  @impl true
  def handle_event("restore_state", %{"content" => content}, socket) do
    case Game.restore_state(content) do
      :ok -> {:noreply, socket}
      {:error, reason} -> {:noreply, put_flash(socket, :error, reason)}
    end
  end

  def select_button_extra_classes(adventure_filename, selected_adventure) do
    if selected_adventure && selected_adventure.file == adventure_filename,
      do: "selected",
      else: ""
  end
end
