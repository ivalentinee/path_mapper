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
    field(:color, :binary)
  end

  def changeset(struct, params, adventure_zip) do
    struct
    |> cast(params, [:name, :owner, :image, :size, :color])
    |> cast_color()
    |> FileStorage.store_image_from_zip(:image, adventure_zip)
    |> validate_required([:name, :owner, :image, :size, :color])
  end

  def cast_color(changeset) do
    if get_change(changeset, :color) do
      changeset
    else
      owner = get_change(changeset, :owner)
      put_change(changeset, :color, color(owner))
    end
  end

  def color("enemy"), do: "#db0909"
  def color("NPC"), do: "#a1a1a1"
  def color(_), do: "#000000"
end
