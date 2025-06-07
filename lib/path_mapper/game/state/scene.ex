defmodule PathMapper.Game.State.Scene do
  use Ecto.Schema

  alias PathMapper.Adventures.Adventure.Scene, as: AdventureScene

  @primary_key false

  embedded_schema do
    field(:index, :integer)
    embeds_one(:map, __MODULE__.Map)
  end

  def initialize(%AdventureScene{map: map}, index) do
    %__MODULE__{index: index, map: __MODULE__.Map.initialize(map)}
  end
end
