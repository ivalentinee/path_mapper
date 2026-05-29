defmodule PathMapper.Game.Actions.Tokens.Find do
  alias PathMapper.Adventures.Adventure.Scene.Token
  alias PathMapper.Game.State
  alias PathMapper.Groups
  alias PathMapper.Groups.Group.Player
  alias PathMapper.Groups.Group.Player.ExtraToken

  def token_exists(%State{} = state, name) when is_binary(name) do
    Enum.find(State.scene(state).tokens, &(&1.data.name == name))
  end

  def find_adventure_token(%State{} = state, index) when is_number(index) do
    Enum.at(State.scene(state).data.tokens, index)
  end

  def find_adventure_token(%State{} = state, name) when is_binary(name) do
    Enum.find(State.scene(state).data.tokens, fn token -> token.name == name end)
  end

  def find_player_token(character_name_or_index)
      when is_binary(character_name_or_index) or is_number(character_name_or_index) do
    case find_player(character_name_or_index) do
      %Player{character_name: character_name, token: token_image} ->
        %Token{
          name: character_name,
          owner: character_name,
          image: token_image,
          size: 1
        }

      _ ->
        nil
    end
  end

  def find_player_extra_token(character_name_or_index, extra_token_index)
      when (is_binary(character_name_or_index) or is_number(character_name_or_index)) and
             is_number(extra_token_index) do
    with %Player{character_name: character_name, extra_tokens: extra_tokens} <-
           find_player(character_name_or_index),
         %ExtraToken{name: name, image: image} <- Enum.at(extra_tokens, extra_token_index) do
      %Token{
        name: "[#{character_name}] #{name}",
        owner: character_name,
        image: image,
        size: 1
      }
    else
      _ -> nil
    end
  end

  defp find_player(character_name) when is_binary(character_name) do
    case Groups.get_loaded() do
      {:ok, group} -> Enum.find(group.players, &(&1.character_name == character_name))
      _ -> nil
    end
  end

  defp find_player(index) when is_number(index) do
    case Groups.get_loaded() do
      {:ok, group} -> Enum.at(group.players, index)
      _ -> nil
    end
  end
end
