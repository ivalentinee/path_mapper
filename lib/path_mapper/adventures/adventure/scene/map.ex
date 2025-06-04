defmodule PathMapper.Adventures.Adventure.Scene.Map do
  use Ecto.Schema

  import Ecto.Changeset
  alias PathMapper.ORAReader
  alias PathMapper.Zip

  @primary_key false

  embedded_schema do
    field(:file, :string)
    field(:width, :integer)
    field(:height, :integer)
    embeds_many(:layers, __MODULE__.Layer)
    embeds_one(:fow, __MODULE__.AdditionalLayer)
  end

  def changeset(struct, params, adventure_zip) do
    struct
    |> cast(read_ora_file(params, adventure_zip), [:file, :width, :height])
    |> validate_required([:file, :width, :height])
    |> cast_embed(:layers, required: true)
    |> cast_embed(:fow)
  end

  defp read_ora_file(params, adventure_zip) when is_map(params) do
    with filename when is_binary(filename) <- params["file"],
         {:ok, ora_file} <- Zip.get_file(adventure_zip, filename),
         {:ok, ora_data} <- ORAReader.read_from_file(ora_file) do
      Map.put(ora_data, :file, params["file"])
    else
      _ -> params
    end
  end
end
