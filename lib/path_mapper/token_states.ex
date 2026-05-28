defmodule PathMapper.TokenStates do
  @states ["alive", "unconscious", "dead", "hidden"]

  defmacro states, do: @states
end
