defmodule PathMapper.Groups.LoadedStorage do
  alias PathMapper.Groups.Group

  def store(%Group{} = group) do
    :persistent_term.put(Group, group)
  end

  def get do
    case :persistent_term.get(Group, nil) do
      nil -> {:error, "No group loaded"}
      group -> {:ok, group}
    end
  end
end
