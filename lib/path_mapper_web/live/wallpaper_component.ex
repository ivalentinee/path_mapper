defmodule PathMapperWeb.WallpaperComponent do
  use PathMapperWeb, :live_component

  def dim_wallpaper_class(game_state) do
    if game_state.surface, do: "wallpaper-dimmed", else: ""
  end
end
