defmodule IronLawCredo.MixProject do
  use Mix.Project

  def project do
    [
      app: :iron_law_credo,
      version: "0.1.0",
      elixir: "~> 1.19",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      description: "Custom Credo checks enforcing Iron Laws for Elixir/Phoenix projects",
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
      {:dialyxir, "~> 1.4", only: :dev, runtime: false}
    ]
  end

  defp package do
    [
      files: ["lib", "mix.exs", "README.md"],
      maintainers: ["Iron Law Credo Contributors"],
      licenses: ["MIT"],
      links: %{"GitHub" => "https://github.com/iron-law/elixir-credo-checks"}
    ]
  end
end
