defmodule PathMapper.Adventures.Adventure.Scene.Token do
  use Ecto.Schema

  import Ecto.Changeset
  alias PathMapper.Adventures.Adventure.FileStorage

  @primary_key false

  embedded_schema do
    field(:name, :string)
    field(:owner, :string)
    field(:image, :string)
    field(:size, :integer)
  end

  def changeset(struct, params, adventure_zip) do
    struct
    |> cast(params, [:name, :owner, :image, :size])
    |> FileStorage.store_image_from_zip(:image, adventure_zip)
    |> validate_required([:name, :owner, :image, :size])
  end

  def color(%__MODULE__{owner: "enemy"}), do: "#db0909"
  def color(%__MODULE__{owner: "NPC"}), do: "#a1a1a1"
  def color(%__MODULE__{}), do: "#000000"
end
