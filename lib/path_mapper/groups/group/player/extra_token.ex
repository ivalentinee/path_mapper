defmodule PathMapper.Groups.Group.Player.ExtraToken do
  use Ecto.Schema

  alias PathMapper.StoredAsset

  import Ecto.Changeset

  @primary_key false

  embedded_schema do
    field(:id, :string)
    field(:name, :string)
    field(:image, :string)
  end

  def changeset(struct, params) do
    struct
    |> cast(params, [:id, :name, :image])
    |> StoredAsset.validate(:image)
    |> validate_required([:id, :name, :image])
  end
end
