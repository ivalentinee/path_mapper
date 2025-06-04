defmodule PathMapper.Adventures.Adventure.Scene.Map.Layer do
  use Ecto.Schema

  @primary_key false

  embedded_schema do
    field(:name, :string)
    field(:src, :binary)
    field(:index, :integer)
    field(:x, :integer)
    field(:y, :integer)
    field(:tags, {:array, :string})
  end
end
