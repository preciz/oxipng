defmodule Oxipng.MixProject do
  use Mix.Project

  @version "0.1.0"
  @source_url "https://github.com/oxipng/oxipng"

  def project do
    [
      app: :oxipng,
      version: @version,
      elixir: "~> 1.15",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      description: description(),
      package: package(),
      docs: docs()
    ]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp deps do
    [
      {:rustler, "~> 0.38.0", optional: true},
      {:rustler_precompiled, "~> 0.9.0"},
      {:ex_doc, "~> 0.40.4", only: :dev, runtime: false}
    ]
  end

  defp description do
    "Elixir wrapper for oxipng, a multithreaded lossless PNG compression optimizer using Rustler."
  end

  defp package do
    [
      licenses: ["MIT"],
      links: %{"GitHub" => @source_url},
      files: [
        "lib",
        "native/oxipng_nif/.cargo",
        "native/oxipng_nif/src",
        "native/oxipng_nif/Cargo.toml",
        "native/oxipng_nif/README.md",
        "Cargo.toml",
        "mix.exs",
        "README.md",
        "LICENSE",
        "checksum-*.exs"
      ]
    ]
  end

  defp docs do
    [
      main: "Oxipng",
      source_url: @source_url,
      extras: ["README.md"]
    ]
  end
end
