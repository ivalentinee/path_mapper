defmodule PathMapper.Adventures.Adventure.Scene do
  use Ecto.Schema

  @primary_key false

  embedded_schema do
    field(:name, :string)
    embeds_one(:map, __MODULE__.Map)
  end
end
