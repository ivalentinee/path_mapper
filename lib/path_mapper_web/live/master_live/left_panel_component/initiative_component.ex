defmodule PathMapperWeb.MasterLive.LeftPanelComponent.InitiativeComponent do
  use PathMapperWeb, :live_component

  alias PathMapper.Game
  alias PathMapper.Game.Palette

  @impl true
  def handle_event("add_initiative", %{"name" => name, "value" => value_str} = params, socket) do
    case Integer.parse(value_str) do
      {value, _} when name != "" ->
        owner = params["owner"] || "enemy"
        Game.run_action([:initiative, :add], %{name: name, value: value, owner: owner})

      _ ->
        :ok
    end

    {:noreply, socket}
  end

  @impl true
  def handle_event("remove_initiative", %{"id" => id}, socket) do
    Game.run_action([:initiative, :remove], id)
    {:noreply, socket}
  end

  @impl true
  def handle_event("reset_initiative", _, socket) do
    Game.run_action([:initiative, :reset], nil)
    {:noreply, socket}
  end

  defp initiative_color(nil), do: "#808080"
  defp initiative_color(owner), do: Palette.resolve(owner)
end
