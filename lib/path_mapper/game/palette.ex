defmodule PathMapper.Game.Palette do
  @moduledoc """
  What colour an owner's marks are drawn in.

  Held in `:persistent_term` rather than in game state, because every drawn
  element is rendered against it and it changes only when the characters do.
  """

  @defaults %{
    "enemy" => "#db0909",
    "npc" => "#a1a1a1",
    "none" => nil
  }

  @doc """
  The colours owners draw in, rebuilt from the characters the store holds.

  A character's id is an owner, and its colour is what that owner's marks are
  drawn in. The three defaults are owners nobody declares.
  """
  def build(characters) when is_list(characters) do
    Map.merge(@defaults, Map.new(characters, &{&1.id, &1.color}))
  end

  def build(_other), do: @defaults

  def store(palette) do
    :persistent_term.put(__MODULE__, palette)
  end

  def get do
    :persistent_term.get(__MODULE__, @defaults)
  end

  def resolve(owner) do
    Map.get(get(), owner, "#000000")
  end
end
