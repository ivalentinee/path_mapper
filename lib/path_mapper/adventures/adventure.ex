defmodule PathMapper.Adventures.Adventure do
  use Ecto.Schema

  @primary_key false

  embedded_schema do
    field(:name, :string)
    embeds_many(:scenes, __MODULE__.Scene)
  end
end
