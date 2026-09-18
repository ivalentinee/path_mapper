defmodule PathMapper.Groups.Group do
  use Ecto.Schema

  import Ecto.Changeset

  @primary_key false

  embedded_schema do
    field(:id, :string)
    field(:title, :string)
    field(:file, :string)
    embeds_many(:players, __MODULE__.Player)
  end

  def changeset(struct, params) do
    struct
    |> cast(params, [:id, :title, :file])
    |> cast_embed(:players, required: true)
    |> validate_required([:id, :title])
  end
end
