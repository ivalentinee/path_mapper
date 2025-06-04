defmodule PathMapper.Adventures.Adventure do
  use Ecto.Schema

  import Ecto.Changeset
  alias PathMapper.Zip

  @primary_key false

  embedded_schema do
    field(:title, :string)
    field(:file, :string)
    embeds_many(:urls, __MODULE__.URL)
    embeds_many(:scenes, __MODULE__.Scene)
  end

  def read(full_path, filename) when is_binary(full_path) and is_binary(filename) do
    with {:ok, adventure_zip} <- Zip.read(full_path),
         {:ok, adventure_manifest_file} <- Zip.get_file(adventure_zip, "manifest.toml"),
         {:ok, adventure_manifest} <- :tomerl.parse(adventure_manifest_file),
         %Ecto.Changeset{} = changeset <-
           changeset(%__MODULE__{}, Map.put(adventure_manifest, "file", filename), adventure_zip),
         {:ok, adventure} <- apply_action(changeset, :insert) do
      {:ok, adventure}
    else
      error -> error
    end
  end

  def changeset(struct, params, adventure_zip) do
    struct
    |> cast(params, [:title, :file])
    |> cast_embed(:urls)
    |> cast_embed(:scenes,
      required: true,
      with: &__MODULE__.Scene.changeset(&1, &2, adventure_zip)
    )
    |> validate_required([:title, :file])
  end
end
