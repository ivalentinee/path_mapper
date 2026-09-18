defmodule PathMapper.StoredAsset do
  @moduledoc """
  Checks that a description's image fields name assets the server actually holds.

  A description arrives after its assets do, and names them by address. Checking
  here means a description that names something absent is refused at the door,
  rather than becoming a broken image a player discovers mid-session.
  """

  alias Ecto.Changeset
  alias PathMapper.FileStorage

  def validate(%Changeset{} = changeset, field) do
    case Changeset.get_field(changeset, field) do
      nil -> changeset
      path -> check(changeset, field, path)
    end
  end

  def exists?(path) when is_binary(path) do
    match?({:ok, _bytes}, FileStorage.read_stored(path))
  end

  defp check(changeset, field, path) when is_binary(path) do
    if exists?(path) do
      changeset
    else
      Changeset.add_error(changeset, field, "names no stored asset: #{path}")
    end
  end

  defp check(changeset, _field, _path), do: changeset
end
