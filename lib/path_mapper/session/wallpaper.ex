defmodule PathMapper.Session.Wallpaper do
  @moduledoc """
  What a viewer sees when no surface is active.

  A piece like any other: it arrives by id, it is replaced by id, and nothing
  holds it. Its `file` names bytes the server already holds, which is the
  wallpaper's content rather than a reference to another piece — so it is
  checked at the door, where a reference to a piece would not be.
  """

  use Ecto.Schema

  import Ecto.Changeset

  alias PathMapper.StoredAsset

  @primary_key false

  embedded_schema do
    field(:id, :string)
    field(:file, :string)
  end

  def changeset(struct, params) do
    struct
    |> cast(params, [:id, :file])
    |> StoredAsset.validate(:file)
    |> validate_required([:id, :file])
  end
end
