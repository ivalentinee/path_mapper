defmodule PathMapper.Game.State do
  use Ecto.Schema

  @primary_key false

  embedded_schema do
    field(:scene, :string)
  end
end
