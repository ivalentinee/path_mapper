defmodule PathMapper.Session.Encode do
  @moduledoc """
  Renders an entity as the command that would declare it.

  Handing the store back in command shape is what makes a round trip trivial: a
  client saves what it is given and replays it unchanged. Anything else would be a
  second format, and a second thing to keep in step.

  Which means emitting the *declaration* and not what was derived from it. A
  stored map carries its layers, its objects, its grid and its size, all read
  out of the file it names — and `kinds/map.yaml` admits four fields under
  `additionalProperties: false`, so a dump carrying the rest was refused by the
  gate it came from. The contract says which fields a kind declares, and is
  asked rather than copied.
  """

  alias PathMapper.Api.Document
  alias PathMapper.Session.Entity

  def command(%Entity{kind: kind, data: data}) do
    declared = Document.declared_fields(kind)

    data |> plain() |> Elixir.Map.take(declared) |> Elixir.Map.put("kind", kind)
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
