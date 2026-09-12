defmodule Oxipng.Native do
  @moduledoc false

  version = Mix.Project.config()[:version]

  base_url =
    Application.compile_env(
      :oxipng,
      :base_url,
      "https://github.com/preciz/oxipng/releases/download/v#{version}"
    )

  use RustlerPrecompiled,
    otp_app: :oxipng,
    crate: "oxipng_nif",
    base_url: base_url,
    force_build: System.get_env("OXIPNG_BUILD") in ["1", "true"] or Mix.env() in [:dev, :test],
    version: version

  def optimize(_data, _opts), do: :erlang.nif_error(:nif_not_loaded)

  def optimize_file(_in_path, _out_path, _preserve_attrs, _opts),
    do: :erlang.nif_error(:nif_not_loaded)

  def create_optimized_from_raw(_data, _width, _height, _color_type, _bit_depth, _opts),
    do: :erlang.nif_error(:nif_not_loaded)

  def version, do: :erlang.nif_error(:nif_not_loaded)
end
