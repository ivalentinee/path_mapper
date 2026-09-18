defmodule PathMapper.Adventures.Adventure.Scene.Token do
  use Ecto.Schema

  import Ecto.Changeset
  alias PathMapper.StoredAsset

  @primary_key false

  embedded_schema do
    field(:id, :string)
    field(:name, :string)
    field(:owner, :string)
    field(:image, :string)
    field(:size, :integer)
  end

  def changeset(struct, params) do
    struct
    |> cast(params, [:id, :name, :owner, :image, :size])
    |> normalize_owner()
    |> StoredAsset.validate(:image)
    |> validate_required([:id, :name, :owner, :size])
  end

  defp normalize_owner(changeset) do
    case get_change(changeset, :owner) do
      owner when is_binary(owner) -> put_change(changeset, :owner, String.downcase(owner))
      _ -> changeset
    end
  end
end
