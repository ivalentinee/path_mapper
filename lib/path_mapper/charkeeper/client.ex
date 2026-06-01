defmodule PathMapper.Charkeeper.Client do
  @moduledoc false

  alias PathMapper.Charkeeper.CharacterData

  def fetch(server, id) do
    url = build_url(server, id)
    http_opts = [timeout: 5_000] ++ ssl_options(server)

    case :httpc.request(:get, {url, []}, http_opts, []) do
      {:ok, {{_, 200, _}, _headers, body}} ->
        parse_response(body)

      {:ok, {{_, status, _}, _, _}} ->
        {:error, {:http_status, status}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp build_url(server, id) do
    scheme = if String.starts_with?(server, ["http://", "https://"]), do: "", else: "https://"
    ~c"#{scheme}#{server}/characters/#{id}.json"
  end

  defp ssl_options(server) do
    if String.starts_with?(server, "http://") do
      []
    else
      cacertfile = Application.get_env(:path_mapper, :cacertfile)

      base = [
        verify: :verify_peer,
        customize_hostname_check: [
          match_fun: :public_key.pkix_verify_hostname_match_fun(:https)
        ]
      ]

      ssl =
        if cacertfile do
          base ++ [cacertfile: String.to_charlist(cacertfile)]
        else
          base ++ [cacerts: :public_key.cacerts_get()]
        end

      [ssl: ssl]
    end
  end

  defp parse_response(body) do
    case Jason.decode(:erlang.list_to_binary(body)) do
      {:ok, json} -> {:ok, build_character_data(json)}
      error -> error
    end
  end

  defp build_character_data(json) do
    info = json["info"] || %{}

    %CharacterData{
      name: json["name"],
      class: info["class"],
      level: json["level"],
      ancestry: info["race"],
      hp_current: get_in(json, ["health", "current"]) || 0,
      hp_temp: get_in(json, ["health", "temp"]) || 0,
      hp_max: get_in(json, ["health", "max"]),
      armor_class: json["armor_class"]
    }
  end
end
