defmodule Oxipng.MixProject do
  use Mix.Project

  @version "0.1.0"
  @source_url "https://github.com/preciz/oxipng"

  def project do
    [
      app: :oxipng,
      version: @version,
      elixir: "~> 1.18",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      description: description(),
      package: package(),
      docs: docs(),
      source_url: @source_url,
      homepage_url: @source_url,
      test_coverage: [
        summary: [threshold: 90],
        ignore_modules: [Oxipng.Native]
      ]
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
      {:ex_doc, "~> 0.40.4", only: :dev, runtime: false},
      {:credo, "~> 1.7.19", only: [:dev, :test], runtime: false},
      {:stream_data, "~> 1.4", only: [:dev, :test]}
    ]
  end

  defp description do
    "Elixir wrapper for oxipng, a multithreaded lossless PNG compression optimizer using Rustler."
  end

  defp package do
    [
      maintainers: ["Barna Kovacs"],
      licenses: ["MIT"],
      links: %{"GitHub" => @source_url},
      files: [
        "lib",
        "native/oxipng_nif/.cargo",
        "native/oxipng_nif/src",
        "native/oxipng_nif/Cargo.toml",
        "native/oxipng_nif/Cargo.lock",
        "native/oxipng_nif/build.rs",
        "native/oxipng_nif/README.md",
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
      homepage_url: @source_url,
      authors: ["Barna Kovacs"],
      extras: ["README.md", "LICENSE"]
    ]
  end
end
