defmodule PathMapperWeb.SessionState.Language do
  alias PathMapperWeb.Plugs.Locale, as: LocalePlug

  def key, do: :language

  def init, do: %{locale: LocalePlug.default_locale()}

  def run_event(_, %{language: state}), do: state
end
