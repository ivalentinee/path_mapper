defmodule PathMapper.Game.Actions.Tokens.Find do
  alias PathMapper.Adventures.Adventure.Scene.Token
  alias PathMapper.Game.GameId
  alias PathMapper.Game.State
  alias PathMapper.Groups
  alias PathMapper.Groups.Group.Player
  alias PathMapper.Groups.Group.Player.ExtraToken
  alias PathMapper.Session.Resolve

  @doc "The placement holding this game id on the active scene, if any."
  def placement_exists(%State{} = state, game_id) when is_binary(game_id) do
    Enum.find(State.scene(state).tokens, &(&1.game_id == game_id))
  end

  def find_adventure_token(%State{} = state, index) when is_number(index) do
    case State.scene(state).data do
      nil -> nil
      data -> Enum.at(data.tokens, index)
    end
  end

  # The active scene first, because a scene may override a token's name, size or
  # owner for itself. Failing that, the store, which holds every token the session
  # was given - including one uploaded on its own, which no scene names.
  def find_adventure_token(%State{} = state, id) when is_binary(id) do
    scene_token =
      case State.scene(state).data do
        nil -> nil
        data -> Enum.find(data.tokens, fn token -> token.id == id end)
      end

    scene_token || stored_token(id)
  end

  defp stored_token(id), do: Resolve.declared_token(id)

  def find_player_token(id_or_index)
      when is_binary(id_or_index) or is_number(id_or_index) do
    case find_player(id_or_index) do
      %Player{} = player -> player_token(player)
      _ -> nil
    end
  end

  @doc """
  A player's own token and the game id its placement always takes.

  The id is derived from the player rather than minted, so a player holds one
  placement of their own token on a scene without any rule saying so: asking
  twice produces the same id, and the second is a duplicate.
  """
  def find_player_placement(id_or_index)
      when is_binary(id_or_index) or is_number(id_or_index) do
    case find_player(id_or_index) do
      %Player{} = player -> {player_token(player), GameId.mint(player.token_id, player.id)}
      _ -> nil
    end
  end

  def find_player_extra_token(id_or_index, extra_token_index)
      when (is_binary(id_or_index) or is_number(id_or_index)) and
             is_number(extra_token_index) do
    with %Player{extra_tokens: extra_tokens} = player <-
           find_player(id_or_index),
         %ExtraToken{} = extra <- Enum.at(extra_tokens, extra_token_index) do
      extra_token(player, extra)
    else
      _ -> nil
    end
  end

  @doc """
  The group token an id refers to: a player's own token, or one of their
  extras. Restore needs this because a player token is synthesised from the
  group rather than declared by a blob.
  """
  def find_group_token(id) when is_binary(id) do
    case Groups.get_loaded() do
      {:ok, group} -> Enum.find_value(group.players, &group_token_with_id(&1, id))
      _ -> nil
    end
  end

  def find_group_token(_id), do: nil

  defp group_token_with_id(%Player{} = player, id) do
    if player.token_id == id do
      player_token(player)
    else
      case Enum.find(List.wrap(player.extra_tokens), &(&1.id == id)) do
        nil -> nil
        extra -> extra_token(player, extra)
      end
    end
  end

  defp player_token(%Player{} = player) do
    %Token{
      id: player.token_id,
      name: player.character_name,
      owner: player.id,
      image: player.token,
      size: 1
    }
  end

  defp extra_token(%Player{} = player, %ExtraToken{} = extra) do
    %Token{
      id: extra.id,
      name: "[#{player.character_name}] #{extra.name}",
      owner: player.id,
      image: extra.image,
      size: 1
    }
  end

  # A binary is a player id, never a character name. The GM panels and the player's
  # own character menu both address a player by the id their group declared.
  defp find_player(id) when is_binary(id) do
    case Groups.get_loaded() do
      {:ok, group} -> Enum.find(group.players, &(&1.id == id))
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
