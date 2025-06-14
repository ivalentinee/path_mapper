defmodule PathMapperWeb.Live.Helpers do
  def with_parsed_index(index_string, callback, return_value \\ nil) do
    case Integer.parse(index_string) do
      {index, _rest} ->
        callback.(index)
        return_value

      _ ->
        return_value
    end
  end

  def serialize_style(style) when is_map(style) do
    Enum.map_join(style, " ", fn {property, value} ->
      "#{property}: #{value};"
    end)
  end
end
