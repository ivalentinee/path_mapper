defmodule PathMapper.FakeCharkeeper do
  @moduledoc """
  A simple Plug-based fake Charkeeper endpoint for testing.
  Returns canned character data for known UUIDs.
  """

  import Plug.Conn

  @characters %{
    "test-uuid-1" => %{
      "name" => "Test Hero",
      "info" => %{"race" => "Human", "class" => "Fighter"},
      "health" => %{"current" => 10, "temp" => 2, "max" => 15},
      "armor_class" => 18,
      "level" => 3
    },
    "test-uuid-2" => %{
      "name" => "Test Mage",
      "info" => %{"race" => "Elf", "class" => "Wizard"},
      "health" => %{"current" => 6, "temp" => 0, "max" => 8},
      "armor_class" => 12,
      "level" => 2
    }
  }

  def init(opts), do: opts

  def call(%{path_info: ["characters", filename]} = conn, _opts) do
    id = String.replace_suffix(filename, ".json", "")

    case @characters[id] do
      nil ->
        send_resp(conn, 404, "")

      data ->
        conn
        |> put_resp_content_type("application/json")
        |> send_resp(200, Jason.encode!(data))
    end
  end

  def call(conn, _opts), do: send_resp(conn, 404, "")

  def characters, do: @characters
end
