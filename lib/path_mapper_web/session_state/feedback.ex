defmodule PathMapperWeb.SessionState.Feedback do
  def key, do: :feedback

  def init do
    %{load_errors: []}
  end

  def run_event({:load_error, errors}, %{feedback: _state}) when is_list(errors) do
    %{load_errors: errors}
  end

  def run_event(:dismiss_load_errors, %{feedback: _state}) do
    %{load_errors: []}
  end

  def run_event(_, %{feedback: state}), do: state
end
