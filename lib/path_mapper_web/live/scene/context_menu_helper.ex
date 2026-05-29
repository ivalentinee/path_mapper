defmodule PathMapperWeb.Scene.ContextMenuHelper do
  def close_other_context_menus(tokens, except_id) when is_list(tokens) do
    tokens
    |> Enum.with_index()
    |> Enum.reject(fn {_token, index} -> "token-#{index}" == except_id end)
    |> Enum.each(fn {_token, index} ->
      Phoenix.LiveView.send_update(PathMapperWeb.Scene.TokenComponent,
        id: "token-#{index}",
        close_context_menu: true
      )
    end)
  end

  def close_other_context_menus(_, _), do: :ok
end
