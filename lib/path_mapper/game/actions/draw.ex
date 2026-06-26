defmodule PathMapper.Game.Actions.Draw do
  alias PathMapper.Game.State
  alias PathMapper.Game.State.Scene.DrawnElement

  @valid_types [:fill, :rect, :line, :circle, :text, :path]

  def action(%State{} = state, [:draw, :add], %{
        type: type,
        color: color,
        owner: owner,
        data: data
      })
      when type in @valid_types and is_binary(color) and is_binary(owner) and is_map(data) do
    id = to_string(System.unique_integer([:positive]))

    element = %DrawnElement{
      id: id,
      type: type,
      color: color,
      owner: owner,
      data: data
    }

    scene = State.scene(state)
    new_scene = %{scene | drawn_elements: scene.drawn_elements ++ [element]}
    {:ok, State.put_scene(state, new_scene)}
  end

  def action(%State{} = state, [:draw, :remove], %{id: id, owner: caller})
      when is_binary(id) and is_binary(caller) do
    scene = State.scene(state)

    case Enum.find(scene.drawn_elements, &(&1.id == id)) do
      nil ->
        {:error, "Element not found"}

      element ->
        if can_erase?(caller, element.owner) do
          new_elements = Enum.reject(scene.drawn_elements, &(&1.id == id))
          new_scene = %{scene | drawn_elements: new_elements}
          {:ok, State.put_scene(state, new_scene)}
        else
          {:error, "Not authorized to erase this element"}
        end
    end
  end

  def action(%State{} = state, [:draw, :clear], %{owner: "GM"}) do
    scene = State.scene(state)
    new_scene = %{scene | drawn_elements: []}
    {:ok, State.put_scene(state, new_scene)}
  end

  def action(%State{}, [:draw, :clear], _) do
    {:error, "Only GM can clear all drawn elements"}
  end

  defp can_erase?("GM", _), do: true
  defp can_erase?(owner, owner), do: true
  defp can_erase?(_, _), do: false
end
