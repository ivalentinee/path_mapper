defmodule PathMapperWeb.Plugs.Locale do
  @moduledoc false

  import Plug.Conn

  @supported_locales ["en", "ru"]
  @default_locale "en"
  @cookie_name "locale"
  @cookie_max_age 365 * 24 * 60 * 60

  def init(opts), do: opts

  def call(conn, _opts) do
    locale = resolve_locale(conn)
    Gettext.put_locale(PathMapperWeb.Gettext, locale)
    conn |> put_session(:locale, locale) |> assign(:locale, locale)
  end

  defp resolve_locale(conn) do
    conn = fetch_cookies(conn)

    with :error <- from_cookie(conn),
         :error <- from_accept_language(conn) do
      @default_locale
    end
  end

  defp from_cookie(conn) do
    case conn.cookies[@cookie_name] do
      locale when locale in @supported_locales -> locale
      _ -> :error
    end
  end

  defp from_accept_language(conn) do
    case get_req_header(conn, "accept-language") do
      [header | _] -> parse_accept_language(header)
      _ -> :error
    end
  end

  defp parse_accept_language(header) do
    header
    |> String.split(",")
    |> Enum.find_value(:error, fn part ->
      lang = part |> String.split(";") |> hd() |> String.trim() |> normalize_locale()
      if lang in @supported_locales, do: lang
    end)
  end

  defp normalize_locale(locale) do
    locale |> String.downcase() |> String.split("-") |> hd()
  end

  def supported_locales, do: @supported_locales
  def default_locale, do: @default_locale
  def cookie_name, do: @cookie_name
  def cookie_max_age, do: @cookie_max_age
end
