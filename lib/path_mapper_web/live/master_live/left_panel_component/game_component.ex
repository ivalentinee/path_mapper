defmodule PathMapperWeb.MasterLive.LeftPanelComponent.GameComponent do
  @moduledoc """
  What the session currently holds, counted by kind.

  It used to name the loaded adventure and the loaded group. Neither exists any
  more — a session is a set of pieces and nothing above them — so there is no
  package to name, and what is worth reporting instead is simply how many of
  each kind arrived.
  """

  use PathMapperWeb, :live_component

  alias PathMapper.Session.Resolve

  @doc "Each kind the session holds, with how many of it there are."
  def held do
    [
      {gettext("Maps"), length(Resolve.surfaces())},
      {gettext("Tokens"), length(Resolve.tokens())},
      {gettext("Characters"), length(Resolve.characters())},
      {gettext("Wallpaper"), if(Resolve.wallpaper(), do: 1, else: 0)}
    ]
  end
end
