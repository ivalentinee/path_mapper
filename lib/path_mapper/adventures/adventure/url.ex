defmodule PathMapper.Adventures.Adventure.URL do
  use Ecto.Schema

  import Ecto.Changeset

  @primary_key false

  embedded_schema do
    field(:name, :string)
    field(:url, :string)
  end

  def changeset(struct, params) do
    struct
    |> cast(params, [:name, :url])
    |> validate_required([:name, :url])
  end
end
