defmodule PathMapper.Adventures.LoadedStorage do
  alias PathMapper.Adventures.Adventure

  def store(%Adventure{} = adventure) do
    :persistent_term.put(Adventure, adventure)
  end

  def get do
    case :persistent_term.get(Adventure, nil) do
      nil -> {:error, "No adventure loaded"}
      adventure -> {:ok, adventure}
    end
  end
end
