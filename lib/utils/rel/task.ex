defmodule Utils.Rel.Task do
  def migrate(app, repo) do
    with app = String.to_atom(app),
         repo = String.to_atom(repo),
         {:ok, _} = Application.ensure_all_started(app),
         path = Application.app_dir(app, "priv/repo/migrations") do
      Ecto.Migrator.run(repo, path, :up, all: true)
    end
  end
end
