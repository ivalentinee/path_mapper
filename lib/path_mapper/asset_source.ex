defmodule PathMapper.AssetSource do
  @moduledoc """
  Where a served asset lives.

  One value, because everything the server serves arrived by upload. The concept
  survives the collapse from three because the URL prefix still needs a name, and
  `Plug.Static` still needs a list of prefixes to serve.
  """

  @upload "upload"

  @all [@upload]

  def all, do: @all

  def upload, do: @upload

  defguard is_source(value) when value in @all
end
