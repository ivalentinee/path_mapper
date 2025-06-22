defmodule PathMapper.Game.Actions.Tokens.Find do
  alias PathMapper.Adventures.Adventure.Scene.Token
  alias PathMapper.Game.State
  alias PathMapper.Groups
  alias PathMapper.Groups.Group.Player

  def token_exists(%State{} = state, name) when is_binary(name) do
    Enum.find(state.scene.tokens, &(&1.data.name == name))
  end

  def find_adventure_token(%State{} = state, index) when is_number(index) do
    Enum.at(state.scene.data.tokens, index)
  end

  def find_adventure_token(%State{} = state, name) when is_binary(name) do
    Enum.find(state.scene.data.tokens, fn token -> token.name == name end)
  end

  def find_player_token(index) when is_number(index) do
    with {:ok, group} <- Groups.get_loaded(),
         %Player{token: token_image, character_name: character_name, color: color} <-
           Enum.at(group.players, index) do
      %Token{
        name: character_name,
        owner: character_name,
        image: token_image,
        size: 1,
        color: color
      }
    else
      _ -> nil
    end
  end

  def find_player_token(character_name) when is_binary(character_name) do
    with {:ok, group} <- Groups.get_loaded(),
         %Player{token: token_image, color: color} <-
           Enum.find(group.players, &(&1.character_name == character_name)) do
      %Token{
        name: character_name,
        owner: character_name,
        image: token_image,
        size: 1,
        color: color
      }
    else
      _ -> nil
    end
  end
end
