defmodule PathMapper.Groups.Group do
  use Ecto.Schema

  import Ecto.Changeset

  @primary_key false

  embedded_schema do
    field(:title, :string)
    field(:file, :string)
    embeds_many(:players, __MODULE__.Player)
  end

  def changeset(struct, params, group_zip) do
    struct
    |> cast(params, [:title, :file])
    |> cast_embed(:players,
      required: true,
      with: &__MODULE__.Player.changeset(&1, &2, group_zip)
    )
    |> validate_required([:title, :file])
  end
end
