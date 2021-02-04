defmodule Utils.MixProject do
  use Mix.Project

  def project do
    [
      app: :utils,
      version: "0.1.0",
      elixir: "~> 1.10",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  def application do
    []
  end

  defp deps do
    [
      {:ecto_sql, "~> 3.5"},
      {:httpoison, "~> 1.5"},
      {:iconv, "~> 1.0"},
      {:jason, "~> 1.1"},
      {:timex, "~> 3.0"},
    ]
  end
end
