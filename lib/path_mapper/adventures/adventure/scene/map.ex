defmodule PathMapper.Adventures.Adventure.Scene.Map do
  use Ecto.Schema

  import Ecto.Changeset
  alias PathMapper.ORAReader
  alias PathMapper.Zip

  @primary_key false
  @default_grid_size 50
  @grid_tag_regex ~r/grid-([0-9]+)/

  embedded_schema do
    field(:file, :string)
    field(:width, :integer)
    field(:height, :integer)
    field(:grid_size, :integer)
    field(:floors, {:array, :integer})
    embeds_many(:layers, __MODULE__.Layer)
    embeds_one(:fow, __MODULE__.AdditionalLayer)
  end

  def changeset(struct, params, adventure_zip) do
    struct
    |> cast(read_ora_file(params, adventure_zip), [:file, :width, :height])
    |> validate_required([:file, :width, :height])
    |> cast_embed(:layers, required: true)
    |> cast_embed(:fow)
    |> get_grid_size()
    |> cast_floors()
    |> validate_required([:grid_size, :floors])
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

  defp get_grid_size(changeset) do
    with [_, grid_size_string] <- get_grid_size_tag(changeset),
         {grid_size, _} <- Integer.parse(grid_size_string) do
      put_change(changeset, :grid_size, grid_size)
    else
      _ -> put_change(changeset, :grid_size, @default_grid_size)
    end
  end

  defp get_grid_size_tag(changeset) do
    layers = get_embed(changeset, :layers)
    fow = get_embed(changeset, :fow)
    all_layers = [fow | layers]

    Enum.find_value(all_layers, fn layer ->
      case get_change(layer, :tags) do
        tags when is_list(tags) -> Enum.find_value(tags, &Regex.run(@grid_tag_regex, &1))
        _ -> nil
      end
    end)
  end

  defp cast_floors(changeset) do
    floors =
      changeset
      |> get_embed(:layers)
      |> Enum.map(&get_change(&1, :floor))
      |> Enum.uniq()
      |> Enum.filter(&is_number/1)
      |> Enum.sort()

    put_change(changeset, :floors, floors)
  end
end
