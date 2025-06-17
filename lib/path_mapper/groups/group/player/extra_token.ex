defmodule PathMapper.Groups.Group.Player.ExtraToken do
  use Ecto.Schema

  alias PathMapper.Groups.Group.FileStorage

  import Ecto.Changeset

  @primary_key false

  embedded_schema do
    field(:name, :string)
    field(:image, :string)
  end

  def changeset(struct, params, group_zip) do
    struct
    |> cast(params, [:name, :image])
    |> FileStorage.store_image_from_zip(:image, group_zip)
    |> validate_required([:name, :image])
  end
end
