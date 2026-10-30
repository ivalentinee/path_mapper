defmodule PathMapper.Game.State.Surface do
  @moduledoc """
  What has happened on one map, while the session runs.

  A *surface* is the role a map plays once there is a game on it. The map is the
  piece — declared, uploaded, replaced by id — and this is the live state beside
  it: where the tokens stand, what has been drawn, which layers are lit. `id` is
  the map's id, because a surface has none of its own.

  `data` holds the declaration this was built against, so a reader does not have
  to go back to the store for every field. `map` holds the live map state, which
  can differ from the declaration — a layer hidden at the table, a grid toggled —
  and when a map is re-declared the two are merged rather than one replacing the
  other.
  """

  use Ecto.Schema

  alias PathMapper.Geometry.Mapper, as: GeometryMapper

  @primary_key false

  embedded_schema do
    field(:id, :string)
    field(:name, :string)
    embeds_one(:map, __MODULE__.Map)
    embeds_one(:data, PathMapper.Session.Map)
    embeds_many(:tokens, __MODULE__.Token)
    embeds_many(:drawn_elements, __MODULE__.DrawnElement)
  end

  @doc "The map this surface shows."
  def displayed_map(%__MODULE__{data: %{} = map}), do: map
  def displayed_map(_surface), do: nil

  @doc """
  The grid a surface's positions are measured against.

  The live map's, not the declaration's: the live one is what the board draws and
  what a game master sees, and the two can differ. Both sides of a copied
  arrangement read it here, because they are one contract and drifted once
  already by each reading its own source.
  """
  def grid_size(%{map: %{grid_size: size}}) when is_integer(size) and size > 0, do: size
  def grid_size(_surface), do: PathMapper.Session.Map.default_grid_size()

  @doc "A surface newly built on a map, with nothing on it yet."
  def initialize(%PathMapper.Session.Map{} = map) do
    %__MODULE__{
      id: map.id,
      name: map.name,
      data: map,
      map: __MODULE__.Map.initialize(map),
      tokens: [],
      drawn_elements: []
    }
  end

  @doc """
  The surface a re-declared map leaves behind.

  A map replaced by id is the same surface with new bytes: what was placed on it
  stays, what was drawn on it stays, and the live map is merged against the new
  declaration rather than replaced by it. A layer keeps whatever the table did to
  it, a new layer arrives initialized, and an object the game master moved keeps
  where they moved it.

  Without this a re-export from GIMP would silently keep the previous export's
  grid, layers and object indices, because nothing else refreshes the live map.
  """
  def rebuild(%__MODULE__{} = held, %PathMapper.Session.Map{} = declared) do
    %{held | data: declared, name: declared.name, map: merged_map(held, declared)}
  end

  defp merged_map(%__MODULE__{map: live, data: previous}, declared) do
    %__MODULE__.Map{
      width: declared.width,
      height: declared.height,
      grid_size: declared.grid_size,
      grid_line_width: declared.grid_line_width,
      show_grid: declared.show_grid,
      layers: merged_layers(declared.layers, live),
      map_objects: merged_objects(declared.map_objects, live, previous)
    }
  end

  defp merged_layers(declared_layers, live) do
    Enum.map(declared_layers, fn declared ->
      case Enum.find(live.layers, &(&1.index == declared.index)) do
        nil -> __MODULE__.Map.Layer.initialize({declared, 0})
        held -> held
      end
    end)
  end

  # An object is matched to its previous self by name, which is what the ORA
  # carries and what a state row now carries with it. A row written before
  # names has only numbers, and is matched by the layer it sits on and where it
  # comes among that layer's objects.
  #
  # Both of those survive the edit that broke this; a global index does not.
  # Objects sort by layer index, so a link added on [L1] to a map whose
  # furniture sits on [L9] lands at the front of the list and shifts every
  # index after it along by one. Reading a row's identity out of the *current*
  # declaration at that index then re-labelled every row and put each object
  # where its neighbour stood. The object kept its own image and its own link,
  # which is why it read as one piece in the wrong place rather than as two
  # pieces swapped.
  defp merged_objects(declared_objects, live, previous) do
    previous_objects = (previous && previous.map_objects) || []
    held = held_entries(live.map_objects, previous_objects)

    {objects, _unclaimed} =
      declared_objects
      |> in_slots()
      |> Enum.map_reduce(held, fn {declared, index, slot}, unclaimed ->
        {claimed, rest} = claim(unclaimed, declared.name, slot)
        {merged_object(declared, index, claimed), rest}
      end)

    objects
  end

  # Where an object comes among the objects of its own layer. Unchanged by a
  # map gaining or losing an object on some other layer, which is the whole
  # difference from the position it has in the flat list.
  defp in_slots(objects) do
    objects
    |> Enum.with_index()
    |> Enum.map_reduce(%{}, fn {object, index}, counts ->
      ordinal = Map.get(counts, object.layer_index, 0)

      {{object, index, {object.layer_index, ordinal}},
       Map.put(counts, object.layer_index, ordinal + 1)}
    end)
    |> elem(0)
  end

  # `previous` is the declaration this state was last reconciled against, and
  # the position in it is what says whether the game master has since moved the
  # object. Found the same way the state row is identified.
  defp held_entries(live_objects, previous_objects) do
    by_slot = Map.new(in_slots(previous_objects), fn {object, _index, slot} -> {slot, object} end)

    live_objects
    |> in_slots()
    |> Enum.map(fn {state, _index, slot} ->
      origin =
        if state.name,
          do: Enum.find(previous_objects, &(&1.name == state.name)),
          else: Map.get(by_slot, slot)

      {state.name, slot, state, origin}
    end)
  end

  # A name first, wherever the row has one; a slot only for the rows that do
  # not. Objects may share a name - a row of identical barrels - so each
  # declared one claims a row and removes it, rather than all of them finding
  # the first.
  defp claim(held, name, slot) do
    case take(held, &named?(&1, name)) do
      {nil, _held} -> take(held, &slotted?(&1, slot))
      found -> found
    end
  end

  defp named?({held_name, _slot, _state, _origin}, name),
    do: not is_nil(name) and held_name == name

  defp slotted?({held_name, held_slot, _state, _origin}, slot),
    do: is_nil(held_name) and held_slot == slot

  defp take(held, matches?) do
    case Enum.split_while(held, &(not matches?.(&1))) do
      {_unmatched, []} -> {nil, held}
      {before, [match | rest]} -> {match, before ++ rest}
    end
  end

  defp merged_object(declared, index, claimed) do
    x = GeometryMapper.to_subpixels(declared.x)
    y = GeometryMapper.to_subpixels(declared.y)

    case claimed do
      {_name, _slot, state, origin} when not is_nil(origin) ->
        moved? =
          state.x != GeometryMapper.to_subpixels(origin.x) or
            state.y != GeometryMapper.to_subpixels(origin.y)

        # Hiding one is a thing the game master does mid-game, the same as
        # moving it, so it survives a re-upload on the same terms: theirs wins
        # where they changed it, and the export wins where they did not.
        %__MODULE__.Map.MapObject{
          index: index,
          name: declared.name,
          layer_index: declared.layer_index,
          x: if(moved?, do: state.x, else: x),
          y: if(moved?, do: state.y, else: y),
          locked: state.locked,
          show: if(state.show != origin.show, do: state.show, else: declared.show)
        }

      _unmatched ->
        %__MODULE__.Map.MapObject{
          index: index,
          name: declared.name,
          layer_index: declared.layer_index,
          x: x,
          y: y,
          locked: true,
          show: declared.show
        }
    end
  end
end
