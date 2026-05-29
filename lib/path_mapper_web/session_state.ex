defmodule PathMapperWeb.SessionState do
  @moduledoc """
  Centralized session state with pluggable partitions.

  Each plugin module defines:
  - `key()` — atom identifying its partition
  - `init()` — initial partition state
  - `run_event(event, full_session_state)` — returns updated partition

  Plugins are composed at mount time based on role (GM vs Player).
  """

  def new(plugins) when is_list(plugins) do
    state = %{plugins: plugins}

    Enum.reduce(plugins, state, fn plugin, acc ->
      Map.put(acc, plugin.key(), plugin.init())
    end)
  end

  def run_event(session_state, event) do
    Enum.reduce(session_state.plugins, session_state, fn plugin, acc ->
      updated_partition = plugin.run_event(event, acc)
      Map.put(acc, plugin.key(), updated_partition)
    end)
  end

  def assign_partitions(socket, session_state) do
    Enum.reduce(session_state.plugins, socket, fn plugin, sock ->
      Phoenix.Component.assign(sock, plugin.key(), Map.get(session_state, plugin.key()))
    end)
  end

  def apply_event(socket, event) do
    new_state = run_event(socket.assigns.session_state, event)

    socket
    |> Phoenix.Component.assign(:session_state, new_state)
    |> assign_partitions(new_state)
  end
end
