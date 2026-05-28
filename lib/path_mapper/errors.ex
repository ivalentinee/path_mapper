defmodule PathMapper.Errors do
  alias Ecto.Changeset
  use Gettext, backend: PathMapperWeb.Gettext

  @spec format_load_error(term()) :: [String.t()]

  def format_load_error({:error, %Changeset{} = changeset}) do
    format_changeset_errors(changeset)
  end

  def format_load_error({:error, {:zip, reason}}) do
    [gettext("Failed to read ZIP file: %{reason}", reason: inspect(reason))]
  end

  def format_load_error({:error, {:toml_parse_error, {line, col, message}}})
      when is_integer(line) and is_integer(col) do
    [
      gettext(
        "Failed to parse manifest.toml at line %{line}, column %{col}: %{message}",
        line: line,
        col: col,
        message: to_string(message)
      )
    ]
  end

  def format_load_error({:error, {:toml_parse_error, error}}) do
    [gettext("Failed to parse manifest.toml: %{error}", error: inspect(error))]
  end

  def format_load_error({:error, message}) when is_binary(message) do
    [message]
  end

  def format_load_error(error) do
    [gettext("Unknown error: %{error}", error: inspect(error))]
  end

  defp format_changeset_errors(%Changeset{} = changeset) do
    changeset
    |> Changeset.traverse_errors(fn {msg, opts} ->
      Gettext.dgettext(PathMapperWeb.Gettext, "errors", msg, opts)
    end)
    |> flatten_error_map([])
  end

  defp collection_label(:scenes), do: gettext("Scene")
  defp collection_label(:tokens), do: gettext("Token")
  defp collection_label(:place_tokens), do: gettext("Placed token")
  defp collection_label(:players), do: gettext("Player")
  defp collection_label(:urls), do: gettext("URL")
  defp collection_label(:extra_tokens), do: gettext("Extra token")
  defp collection_label(:layers), do: gettext("Layer")
  defp collection_label(:map_objects), do: gettext("Map object")
  defp collection_label(_), do: nil

  defp flatten_error_map(errors, path) when is_map(errors) do
    Enum.flat_map(errors, fn {key, value} ->
      flatten_error_map(value, path ++ [key])
    end)
  end

  defp flatten_error_map(errors, path) when is_list(errors) do
    collection_key = List.last(path)
    label = collection_label(collection_key)

    errors
    |> Enum.with_index()
    |> Enum.flat_map(fn
      {error, _index} when is_binary(error) ->
        ["#{format_path(path)}: #{error}"]

      {nested, index} when is_map(nested) ->
        prefix = if label, do: "#{label} ##{index + 1}", else: "#{collection_key}.#{index}"
        parent_path = Enum.slice(path, 0..-2//1)
        flatten_error_map(nested, parent_path ++ [prefix])

      {nested, index} when is_list(nested) ->
        prefix = if label, do: "#{label} ##{index + 1}", else: "#{collection_key}.#{index}"
        parent_path = Enum.slice(path, 0..-2//1)
        flatten_error_map(nested, parent_path ++ [prefix])
    end)
  end

  defp format_path(path) do
    Enum.map_join(path, ": ", &to_string/1)
  end

  def display_errors(%Changeset{} = changeset) do
    changeset
    |> Changeset.traverse_errors(fn {msg, opts} ->
      Regex.replace(~r"%{(\w+)}", msg, fn _, key ->
        opts |> Keyword.get(String.to_existing_atom(key), key) |> to_string()
      end)
    end)
    |> Jason.encode!()
  end
end
