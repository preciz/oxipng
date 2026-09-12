defmodule Oxipng.Native do
  @moduledoc false

  use Rustler,
    otp_app: :oxipng,
    crate: "oxipng_nif"

  def optimize(_data, _opts), do: :erlang.nif_error(:nif_not_loaded)

  def optimize_file(_in_path, _out_path, _preserve_attrs, _opts),
    do: :erlang.nif_error(:nif_not_loaded)

  def create_optimized_from_raw(_data, _width, _height, _color_type, _bit_depth, _opts),
    do: :erlang.nif_error(:nif_not_loaded)

  def version, do: :erlang.nif_error(:nif_not_loaded)
end
