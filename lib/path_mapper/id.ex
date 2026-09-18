defmodule PathMapper.Id do
  @moduledoc """
  The id an entity carries.

  Two letters for the kind, four digits for the series, ten for the entity:
  `tk0001-0000000042`. Ids are unique everywhere rather than within a document or
  a campaign, because the same token can be a player's in one adventure and an NPC
  in another, and it is the same token.

  Nothing reads the older, narrower form. A blob carrying one fails to parse,
  which is the intent: a stale blob should stop rather than load wrongly.
  """

  @series_digits 4
  @entity_digits 10

  @pattern ~r/^([a-z]{2}\d{#{@series_digits}}-\d{#{@entity_digits}})-(.+?)(\.[A-Za-z0-9]+)?$/

  @doc """
  Splits a filename into its id and the descriptive part, without extension.
  """
  def parse(filename) when is_binary(filename) do
    case Regex.run(@pattern, Path.basename(filename)) do
      [_, id, rest] -> {:ok, id, rest}
      [_, id, rest, _ext] -> {:ok, id, rest}
      _ -> :error
    end
  end

  @doc "The id a filename carries, or nil."
  def of(filename) when is_binary(filename) do
    case parse(filename) do
      {:ok, id, _rest} -> id
      :error -> nil
    end
  end

  def of(_filename), do: nil

  @doc "An id for something created at runtime rather than authored."
  def generate(prefix) when is_binary(prefix) do
    suffix = :rand.uniform(round(:math.pow(10, @entity_digits))) - 1
    "#{prefix}-#{String.pad_leading(to_string(suffix), @entity_digits, "0")}"
  end
end
