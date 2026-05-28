defmodule PathMapper.Game.State.Scene.Token do
  use Ecto.Schema

  import Ecto.Changeset

  require PathMapper.TokenStates
  import PathMapper.TokenStates, only: [states: 0]

  alias PathMapper.Adventures.Adventure.Scene.Token, as: AdventureToken
  alias PathMapper.Geometry.Mapper, as: GeometryMapper

  @primary_key false

  embedded_schema do
    field(:x, :integer)
    field(:y, :integer)
    field(:state, :string)
    field(:drag_x, :integer)
    field(:drag_y, :integer)
    field(:size, :integer)
    field(:color, :string)
    embeds_one(:data, AdventureToken)
  end

  def build(params, %AdventureToken{} = data) do
    %__MODULE__{}
    |> cast(params, [:x, :y, :state, :size, :color])
    |> validate_inclusion(:state, states())
    |> put_embed(:data, data)
    |> apply_action(:insert)
  end

  def to_place_records(tokens) when is_list(tokens) do
    records = Enum.map_join(tokens, ",\n", &to_place_record/1)
    Enum.join(["place_tokens = [", records, "]"], "\n")
  end

  defp to_place_record(%__MODULE__{} = token) do
    token_object =
      "{ name = \"#{token.data.name}\", x = #{token.x}, y = #{token.y}, state = \"#{token.state}\", subpixel = #{GeometryMapper.subpixel_factor()} }"

    indent = "        "
    "#{indent}#{token_object}"
  end
end
