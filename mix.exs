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
    [mod: {Utils.Application, []}, extra_applications: [:logger]]
  end

  defp deps do
    [
      {:ecto_sql, "~> 3.5"},
      {:ex_aws, "~> 2.2"},
      {:ex_aws_s3, "~> 2.3"},
      {:httpoison, "~> 1.5"},
      {:iconv, "~> 1.0"},
      {:jason, "~> 1.1"},
      {:plug, "~> 1.11"},
      {:joken, "~> 2.4"},
      {:tesla, "~> 1.4"},
      {:timex, "~> 3.0"},
    ]
  end
end
