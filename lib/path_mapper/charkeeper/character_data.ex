defmodule PathMapper.Charkeeper.CharacterData do
  @moduledoc """
  What Charkeeper is consulted for: the numbers that change during play.

  Class and ancestry are not among them. A character's class is the game
  master's, declared in the `.pmcharacter` and the same all evening; this
  carried its own copy, read from a field the service had moved, so it was
  nil on screen where the declared one would have been right.
  """

  defstruct [:name, :level, :hp_current, :hp_temp, :hp_max, :armor_class]
end
