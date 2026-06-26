defmodule PathMapper.MapTools.ToolConfig do
  @moduledoc false

  @configs %{
    # Measurement tools
    ruler: %{
      snap_mode: "center_or_corner",
      interaction: "drag",
      allowed_buttons: "both",
      path_mode: "measure"
    },
    pointer: %{snap_mode: nil, interaction: "drag", allowed_buttons: "both", path_mode: "none"},
    burst: %{
      snap_mode: "center_or_corner",
      interaction: "drag",
      allowed_buttons: "both",
      path_mode: "none"
    },
    emanation: %{
      snap_mode: "center_or_corner",
      interaction: "drag",
      allowed_buttons: "both",
      path_mode: "none"
    },
    cone: %{
      snap_mode: "center_or_corner",
      interaction: "drag",
      allowed_buttons: "both",
      path_mode: "none"
    },
    line: %{
      snap_mode: "center_or_corner",
      interaction: "drag",
      allowed_buttons: "both",
      path_mode: "none"
    },
    # Map tool
    map: %{snap_mode: nil, interaction: "pan", allowed_buttons: "lmb", path_mode: "none"},
    # Drawing tools
    fill: %{snap_mode: "center", interaction: "drag", allowed_buttons: "lmb", path_mode: "none"},
    rect: %{snap_mode: nil, interaction: "drag", allowed_buttons: "both", path_mode: "none"},
    draw_line: %{
      snap_mode: "center_or_corner",
      interaction: "drag",
      allowed_buttons: "both",
      path_mode: "commit"
    },
    draw_circle: %{
      snap_mode: "center_or_corner",
      interaction: "drag",
      allowed_buttons: "both",
      path_mode: "none"
    },
    text: %{snap_mode: nil, interaction: "prompt", allowed_buttons: "lmb", path_mode: "none"},
    freeform: %{
      snap_mode: nil,
      interaction: "freeform",
      allowed_buttons: "lmb",
      path_mode: "none"
    },
    eraser: %{snap_mode: nil, interaction: "drag", allowed_buttons: "lmb", path_mode: "none"}
  }

  def get(tool) when is_atom(tool), do: @configs[tool]
  def get(_), do: nil

  def tools, do: Map.keys(@configs)
end
