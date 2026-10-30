defmodule PathMapper.Session.Map.MapObject.Link do
  @moduledoc """
  A way from one map to another, written on the object that carries it.

  The author types `[link <property>… <map-id>]` into a layer name in GIMP and the
  ORA reader hands it here as one string. The target is the last word; everything
  before it is a property, written as `word`, `key=value` or `key="value with
  spaces"`.

  `gm` and `title` are cast to fields of their own rather than read out of the
  property map, because `[link gm=false …]` would otherwise hide a link its author
  had just un-hidden — a non-empty string is truthy, and `"false"` is a non-empty
  string. Everything else is kept untouched in `properties`, unfiltered and
  unvalidated, so a map drawn today still reads when a later version gives one of
  those words a meaning.
  """

  use Ecto.Schema

  alias PathMapper.Id

  @primary_key false

  embedded_schema do
    field(:target, :string)
    field(:gm, :boolean, default: false)
    field(:title, :string)
    field(:properties, :map, default: %{})
  end

  @doc """
  The link a tag carries, or nil where it carries none.

  A tag with nothing after `link`, or whose last word is not an id, is not a link
  rather than a link to nowhere — there is nothing a reader could be offered.
  """
  def parse("link " <> rest) do
    case tokenize(rest) do
      [] -> nil
      tokens -> build(List.last(tokens), Enum.drop(tokens, -1))
    end
  end

  def parse(_tag), do: nil

  @doc "The first link among an object's tags, or nil."
  def from_tags(tags) when is_list(tags), do: Enum.find_value(tags, &parse/1)
  def from_tags(_tags), do: nil

  defp build(target, properties) do
    with true <- Id.valid?(target),
         read <- Elixir.Map.new(properties, &property/1) do
      %__MODULE__{
        target: target,
        gm: truthy?(read["gm"]),
        title: title_of(read["title"]),
        properties: Elixir.Map.drop(read, ~w[gm title])
      }
    else
      _ -> nil
    end
  end

  # A word on its own is present, which is true. Anything after the first `=` is the
  # value, so a value may itself contain one.
  defp property(token) do
    case String.split(token, "=", parts: 2) do
      [key] -> {key, true}
      [key, value] -> {key, unquote_value(value)}
    end
  end

  defp unquote_value(<<?", rest::binary>>) do
    String.trim_trailing(rest, "\"")
  end

  defp unquote_value(value), do: value

  defp truthy?(true), do: true
  defp truthy?(value) when is_binary(value), do: String.downcase(value) not in ~w[false no 0]
  defp truthy?(_value), do: false

  defp title_of(true), do: nil
  defp title_of(value) when is_binary(value), do: value
  defp title_of(_value), do: nil

  # Whitespace separates tokens, except inside double quotes. There is no escape:
  # the tag itself ended at the first `]`, so a value cannot contain one, and the
  # author has no way to write a quote inside a quoted value either.
  defp tokenize(rest) do
    ~r/"[^"]*"|\S+/
    |> Regex.scan(rest)
    |> Enum.map(&hd/1)
    |> merge_quoted()
    |> Enum.reject(&(&1 == ""))
  end

  # `title="Abandoned Castle"` arrives from the scan as `title="Abandoned` and
  # `Castle"`, so a token holding one quote takes the following ones until the pair
  # closes.
  defp merge_quoted(tokens), do: merge_quoted(tokens, [])

  defp merge_quoted([], done), do: Enum.reverse(done)

  defp merge_quoted([token | rest], done) do
    if open_quote?(token) do
      {tail, remaining} = Enum.split_while(rest, &(not String.ends_with?(&1, "\"")))
      {closing, remaining} = Enum.split(remaining, 1)
      merge_quoted(remaining, [Enum.join([token | tail] ++ closing, " ") | done])
    else
      merge_quoted(rest, [token | done])
    end
  end

  defp open_quote?(token) do
    token |> String.graphemes() |> Enum.count(&(&1 == "\"")) == 1
  end
end
