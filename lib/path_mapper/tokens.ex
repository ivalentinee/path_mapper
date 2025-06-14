defmodule PathMapper.Tokens do
  alias PathMapper.Tokens.Token

  @tokens [
    %Token{name: "goblin", owner: "enemy", image: "/tokens/goblin.png", size: 1},
    %Token{name: "token 2", owner: "enemy", image: "", size: 1},
    %Token{name: "token 3", owner: "enemy", image: "", size: 1},
    %Token{name: "token 4", owner: "enemy", image: "", size: 1}
  ]

  def all do
    @tokens
  end

  def get(name) when is_binary(name) do
    Enum.find(@tokens, fn token -> token.name == name end)
  end

  def get(index) when is_number(index) do
    Enum.at(@tokens, index)
  end
end
