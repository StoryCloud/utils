defmodule Utils.Application do
  use Application

  @app :utils

  def start(_type, _args) do
    with children = get_children(@app) do
      Supervisor.start_link children, strategy: :one_for_one, name: Utils.Supervisor
    end
  end

  defp get_children(app) do
    with {:ok, config} <- Application.fetch_env(app, Box.Auth) do
      [{Utils.Box.Auth, config}]
    else
      _ -> []
    end
  end
end
