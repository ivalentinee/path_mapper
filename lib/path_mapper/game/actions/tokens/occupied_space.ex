defmodule PathMapper.Game.Actions.Tokens.OccupiedSpace do
  @enforce_keys [:from, :to]
  defstruct [:from, :to]
end
