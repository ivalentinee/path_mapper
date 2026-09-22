defmodule PathMapper.Game.State.Scene.Token do
  use Ecto.Schema

  import Ecto.Changeset

  require PathMapper.TokenStates
  import PathMapper.TokenStates, only: [states: 0]

  alias PathMapper.Adventures.Adventure.Scene.Token, as: AdventureToken
  alias PathMapper.Geometry.Mapper, as: GeometryMapper

  @primary_key false

  embedded_schema do
    field(:game_id, :string)
    field(:name, :string)
    field(:x, :integer)
    field(:y, :integer)
    field(:state, :string)
    field(:drag_x, :integer)
    field(:drag_y, :integer)
    field(:size, :integer)
    field(:owner, :string)
    embeds_one(:data, AdventureToken)
  end

  def build(params, %AdventureToken{} = data) do
    %__MODULE__{}
    |> cast(params, [:game_id, :name, :x, :y, :state, :size, :owner])
    |> validate_required([:game_id, :owner])
    |> validate_inclusion(:state, states())
    |> put_embed(:data, data)
    |> apply_action(:insert)
  end

  @doc """
  What a placement is called.

  Its own name where it has one, and the name of the token it was placed from
  where it has not - which is the ordinary case. An empty string is no name
  rather than a name, so clearing works whether the interface sends nil or "".
  """
  def displayed_name(%__MODULE__{name: name}) when is_binary(name) and name != "", do: name
  def displayed_name(%__MODULE__{data: %{name: name}}), do: name

  @doc """
  An arrangement written back out as `place_tokens`, for pasting into an adventure.

  Positions are in grid cells rather than pixels, so re-exporting a map at another
  resolution does not invalidate them. A fact the placement shares with its
  declaration - its owner, its name - is left out, because the entry says what
  differs and the declaration says the rest.
  """
  def to_place_records(tokens, grid_size) when is_list(tokens) and is_number(grid_size) do
    records = Enum.map_join(tokens, ",\n", &to_place_record(&1, grid_size))
    Enum.join(["place_tokens = [", records, "]"], "\n")
  end

  defp to_place_record(%__MODULE__{} = token, grid_size) do
    x = GeometryMapper.to_cells(token.x, grid_size)
    y = GeometryMapper.to_cells(token.y, grid_size)

    token_object =
      "{ game_id = \"#{token.game_id}\", x = #{x}, y = #{y}, state = \"#{token.state}\"#{optional_parts(token)} }"

    indent = "        "
    "#{indent}#{token_object}"
  end

  # The name is always stated, resolved, even where it is the declaration's: the
  # converter that reads a copy holds the entry and not the token roster, so a
  # name present only sometimes would send it looking for one.
  #
  # The owner is stated only where it differs, because nothing reading a copy
  # needs an owner it could not otherwise work out.
  defp optional_parts(%__MODULE__{} = token) do
    owner_part(token) <> ", name = \"#{displayed_name(token)}\""
  end

  defp owner_part(%__MODULE__{owner: owner, data: %{owner: owner}}), do: ""
  defp owner_part(%__MODULE__{owner: owner}), do: ", owner = \"#{owner}\""
end
