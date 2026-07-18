defmodule ExtraCredo.MixProject do
  use Mix.Project

  def project do
    [
      app: :extra_credo,
      version: "0.1.0",
      elixir: "~> 1.19",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      aliases: aliases(),
      description: "Custom Credo checks enforcing Extra rules for Elixir/Phoenix projects",
      package: package()
    ]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp deps do
    [
      {:credo, "~> 1.7"},
      {:dialyxir, "~> 1.4", runtime: false}
    ]
  end

  defp aliases do
    [
      lint: "credo"
    ]
  end

  defp package do
    [
      files: ["lib", "mix.exs", "README.md"],
      maintainers: ["Extra Credo Contributors"],
      licenses: ["MIT"],
      links: %{"GitHub" => "https://github.com/dvadell/extra_credo"}
    ]
  end
end
