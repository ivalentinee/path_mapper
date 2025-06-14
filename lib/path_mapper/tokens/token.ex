defmodule PathMapper.Tokens.Token do
  use Ecto.Schema

  @primary_key false

  embedded_schema do
    field(:name, :string)
    field(:owner, :string)
    field(:image, :string)
    field(:size, :integer)
  end
end
