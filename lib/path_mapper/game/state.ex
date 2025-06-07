defmodule PathMapper.Game.State do
  use Ecto.Schema

  @primary_key false

  embedded_schema do
    embeds_one(:scene, __MODULE__.Scene)
  end
end
