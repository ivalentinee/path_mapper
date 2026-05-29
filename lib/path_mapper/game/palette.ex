defmodule PathMapper.Game.Palette do
  @defaults %{
    "enemy" => "#db0909",
    "npc" => "#a1a1a1",
    "none" => nil
  }

  def build(group) do
    player_colors =
      if group do
        Map.new(group.players, &{&1.character_name, &1.color})
      else
        %{}
      end

    Map.merge(@defaults, player_colors)
  end

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
