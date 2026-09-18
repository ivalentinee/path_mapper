defmodule PathMapperWeb.MasterLive.LeftPanelComponent.GameComponent do
  @moduledoc """
  What the session currently holds.

  One panel rather than two, because neither half does anything any more: the
  client composes, and this reports. Two tabs to read four lines was two clicks
  where one would do.
  """

  use PathMapperWeb, :live_component
end
