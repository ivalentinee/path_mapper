defmodule PathMapper.Adventures.Adventure.Scene.Map do
  use Ecto.Schema

  @primary_key false

  embedded_schema do
    field(:width, :integer)
    field(:height, :integer)
    embeds_one(:fow, __MODULE__.AdditionalLayer)
    embeds_many(:layers, __MODULE__.Layer)
  end
end
