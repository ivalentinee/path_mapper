defmodule PathMapper.Session.Encode do
  @moduledoc """
  Renders an entity as the command that would declare it.

  Handing the store back in command shape is what makes a round trip trivial: a
  client saves what it is given and replays it unchanged. Anything else would be a
  second format, and a second thing to keep in step.
  """

  alias PathMapper.Session.Entity

  def command(%Entity{kind: kind, data: data}) do
    data |> plain() |> Elixir.Map.put("kind", kind)
  end

  defp plain(%_struct{} = struct) do
    struct |> Elixir.Map.from_struct() |> Elixir.Map.drop([:__meta__]) |> plain()
  end

  defp plain(%{} = map) do
    Elixir.Map.new(map, fn {key, value} -> {to_string(key), plain(value)} end)
  end

  defp plain(list) when is_list(list), do: Enum.map(list, &plain/1)

  defp plain(value), do: value
end
