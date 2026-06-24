defmodule PathMapperWeb.MasterLive.LeftPanelComponent.TokensComponent.AddAdhoc do
  use PathMapperWeb, :live_component

  require PathMapperWeb.MasterLive.LeftPanelState

  alias PathMapper.Game

  @impl true
  def update(assigns, socket) do
    socket =
      socket
      |> assign(assigns)
      |> assign_new(:label, fn -> "" end)
      |> assign_new(:owner, fn -> "enemy" end)
      |> assign_new(:size, fn -> 1 end)

    {:ok, socket}
  end

  @impl true
  def handle_event("set_owner", %{"owner" => owner}, socket) do
    {:noreply, assign(socket, :owner, owner)}
  end

  @impl true
  def handle_event("set_size", %{"size" => size_str}, socket) do
    size = String.to_integer(size_str)
    {:noreply, assign(socket, :size, size)}
  end

  @impl true
  def handle_event("create_adhoc", %{"label" => label}, socket) do
    trimmed = String.trim(label)

    if trimmed != "" do
      Game.run_action([:tokens, :add_adhoc], %{
        label: trimmed,
        owner: socket.assigns.owner,
        size: socket.assigns.size
      })
    end

    {:noreply, socket}
  end
end
