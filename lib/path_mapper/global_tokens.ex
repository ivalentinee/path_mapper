defmodule PathMapper.GlobalTokens do
  use Agent

  require Logger

  alias PathMapper.Adventures.Adventure.Scene.Token, as: AdventureToken
  alias PathMapper.FileStorage

  @storage_subdirectory "global"

  defmodule Entry do
    @moduledoc false
    defstruct [:token, :group, :tags]
  end

  def start_link(_) do
    case scan_directory() do
      {:ok, entries} -> Agent.start_link(fn -> entries end, name: __MODULE__)
      {:error, _} -> Agent.start_link(fn -> [] end, name: __MODULE__)
    end
  end

  def get, do: Agent.get(__MODULE__, & &1)

  def reload do
    case scan_directory() do
      {:ok, entries} ->
        Agent.update(__MODULE__, fn _state -> entries end)
        :ok

      _ ->
        :ok
    end
  end

  defp scan_directory do
    base_path = Application.get_env(:path_mapper, :global_tokens_path, "tokens")

    if File.dir?(base_path) do
      FileStorage.initialize(@storage_subdirectory)
      entries = scan_recursive(base_path, nil, 0)
      FileStorage.cleanup(@storage_subdirectory, Enum.map(entries, & &1.token))
      {:ok, entries}
    else
      {:error, :no_directory}
    end
  end

  @max_depth 3

  defp scan_recursive(_path, _group, depth) when depth >= @max_depth, do: []

  defp scan_recursive(path, group, depth) do
    case File.ls(path) do
      {:ok, files} ->
        files
        |> Enum.sort()
        |> Enum.flat_map(&process_file(Path.join(path, &1), &1, group, depth))

      _ ->
        []
    end
  end

  defp process_file(full_path, filename, group, depth) do
    cond do
      File.dir?(full_path) ->
        scan_recursive(full_path, group || filename, depth + 1)

      image_file?(filename) ->
        case build_entry(full_path, filename, group) do
          {:ok, entry} -> [entry]
          _ -> []
        end

      true ->
        []
    end
  end

  defp image_file?(filename) do
    ext = filename |> Path.extname() |> String.downcase()
    ext in [".png", ".jpg", ".jpeg", ".webp"]
  end

  defp build_entry(full_path, filename, group) do
    with {:ok, image_data} <- File.read(full_path),
         {:ok, stored_path} <- FileStorage.store_image(image_data, @storage_subdirectory) do
      {name, tags} = parse_filename(filename)
      size = extract_size(tags)

      token = %AdventureToken{
        name: name,
        owner: "none",
        image: stored_path,
        size: size
      }

      {:ok, %Entry{token: token, group: group, tags: tags}}
    end
  end

  defp parse_filename(filename) do
    base = Path.rootname(filename)

    case Regex.run(~r/^(.*?)\[([^\]]*)\]$/, base) do
      [_, name_part, tags_part] ->
        name = format_name(name_part)

        tags =
          tags_part |> String.split(",") |> Enum.map(&String.trim/1) |> Enum.reject(&(&1 == ""))

        {name, tags}

      _ ->
        {format_name(base), []}
    end
  end

  defp format_name(raw) do
    raw
    |> String.replace(~r/[-_]/, " ")
    |> String.split()
    |> Enum.map_join(" ", &String.capitalize/1)
  end

  defp extract_size(tags) do
    Enum.find_value(tags, 1, &parse_size_tag/1)
  end

  defp parse_size_tag(tag) do
    case Regex.run(~r/^size-(\d+)$/, tag) do
      [_, n] -> String.to_integer(n)
      _ -> nil
    end
  end
end
