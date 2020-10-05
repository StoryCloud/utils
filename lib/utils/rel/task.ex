defmodule Utils.Rel.Task do
  alias Depos.{Repo}

  def migrate(app) do
    with app = String.to_atom(app),
         {:ok, _} = Application.ensure_all_started(app),
         path = Application.app_dir(app, "priv/repo/migrations") do
      Ecto.Migrator.run(Repo, path, :up, all: true)
    end
  end
end
