defmodule Oxipng do
  @moduledoc """
  Elixir bindings for [oxipng](https://github.com/oxipng/oxipng), a PNG optimizer
  written in Rust.

  Calls are synchronous and run via Rustler NIFs on dirty CPU schedulers. The
  calling process waits for the result while normal BEAM schedulers remain available.

  Compression is lossless by default. `scale_16: true` reduces precision, and
  `optimize_alpha: true` can change the RGB values of fully transparent pixels.
  Stripping color metadata can affect how an image is displayed.

  ## Examples

      # Optimize PNG binary in memory
      {:ok, optimized_binary} = Oxipng.optimize(png_data)

      # Choose a preset and metadata stripping policy
      {:ok, optimized_binary} = Oxipng.optimize(png_data, level: 4, strip: :safe)

      # Optimize using bang variant
      optimized_binary = Oxipng.optimize!(png_data)

      # Optimize a file in-place
      {:ok, result} = Oxipng.optimize_file("image.png")
      #=> {:ok, %{in_bytes: 12450, out_bytes: 8320}}

      # Optimize a file to a new location
      {:ok, result} = Oxipng.optimize_file("image.png", "image_optimized.png", level: 6)

      # Create an optimized PNG directly from raw RGBA pixel data
      {:ok, png} = Oxipng.create_optimized_from_raw(raw_rgba_bytes, 100, 100)
  """

  alias Oxipng.{Error, Native, Options}

  @type optimization_stats :: %{
          in_bytes: non_neg_integer(),
          out_bytes: non_neg_integer()
        }

  @doc """
  Optimizes a PNG binary image in memory.

  ## Options

  See `Oxipng.Options` for available options and presets.

  ## Returns

    * `{:ok, binary}` on success.
    * `{:error, reason}` if the input is not a valid PNG or optimization fails.
  """
  @spec optimize(binary(), keyword() | map() | Options.t()) ::
          {:ok, binary()} | {:error, String.t()}
  def optimize(png_data, opts \\ [])

  def optimize(png_data, opts) when is_binary(png_data) do
    with {:ok, options} <- Options.new(opts) do
      nif_opts = Options.to_nif_map(options)
      Native.optimize(png_data, nif_opts)
    end
  end

  def optimize(data, _opts) do
    {:error, "Expected binary PNG data, got: #{inspect(data)}"}
  end

  @doc """
  Same as `optimize/2`, but returns the optimized binary directly or raises an `Oxipng.Error`.
  """
  @spec optimize!(binary(), keyword() | map() | Options.t()) :: binary()
  def optimize!(png_data, opts \\ []) do
    case optimize(png_data, opts) do
      {:ok, optimized} -> optimized
      {:error, reason} -> raise Error, message: reason
    end
  end

  @doc """
  Optimizes a PNG file on disk.

  If `out_path` is omitted or `nil`, the input file will be optimized in-place.

  ## Parameters

    * `in_path` - Path to the source PNG file.
    * `out_path` - (Optional) Destination path. If not provided or `nil`, `in_path` is overwritten.
    * `opts` - (Optional) Optimization options (see `Oxipng.Options`).

  ## Returns

    * `{:ok, %{in_bytes: in_size, out_bytes: out_size}}` on success.
    * `{:error, reason}` on failure.
  """
  @spec optimize_file(
          Path.t(),
          Path.t() | nil | keyword() | map() | Options.t(),
          keyword() | map() | Options.t()
        ) :: {:ok, optimization_stats()} | {:error, String.t()}
  def optimize_file(in_path, out_path_or_opts \\ nil, opts \\ [])

  def optimize_file(in_path, out_path, opts) when is_binary(out_path) or is_nil(out_path) do
    do_optimize_file(in_path, out_path, opts)
  end

  def optimize_file(in_path, opts, []) when is_list(opts) or is_map(opts) do
    do_optimize_file(in_path, nil, opts)
  end

  defp do_optimize_file(in_path, out_path, opts) do
    with {:ok, options} <- Options.new(opts) do
      nif_opts = Options.to_nif_map(options)
      preserve_attrs = options.preserve_attrs

      case Native.optimize_file(
             to_string(in_path),
             out_path && to_string(out_path),
             preserve_attrs,
             nif_opts
           ) do
        {:ok, {in_bytes, out_bytes}} ->
          {:ok, %{in_bytes: in_bytes, out_bytes: out_bytes}}

        {:error, reason} ->
          {:error, reason}
      end
    end
  end

  @doc """
  Same as `optimize_file/3`, but returns `%{in_bytes: in_bytes, out_bytes: out_bytes}`
  or raises `Oxipng.Error`.
  """
  @spec optimize_file!(
          Path.t(),
          Path.t() | nil | keyword() | map() | Options.t(),
          keyword() | map() | Options.t()
        ) :: optimization_stats()
  def optimize_file!(in_path, out_path_or_opts \\ nil, opts \\ []) do
    case optimize_file(in_path, out_path_or_opts, opts) do
      {:ok, stats} -> stats
      {:error, reason} -> raise Error, message: reason
    end
  end

  @doc """
  Creates an optimized PNG directly from raw uncompressed pixel data.

  ## Parameters

    * `data` - Raw pixel binary.
    * `width` - Image width in pixels.
    * `height` - Image height in pixels.
    * `color_type` - One of `:rgba` (default), `:rgb`, `:grayscale`, `:grayscale_alpha`,
      or `{:indexed, palette_binary}`.
    * `bit_depth` - `1`, `2`, `4`, `8` (default), or `16`.
    * `opts` - Optimization options (see `Oxipng.Options`).

  ## Returns

    * `{:ok, binary}` containing the optimized PNG.
    * `{:error, reason}` on failure.
  """
  @spec create_optimized_from_raw(
          binary(),
          pos_integer(),
          pos_integer(),
          atom() | tuple(),
          1 | 2 | 4 | 8 | 16,
          keyword() | map() | Options.t()
        ) :: {:ok, binary()} | {:error, String.t()}
  def create_optimized_from_raw(
        data,
        width,
        height,
        color_type \\ :rgba,
        bit_depth \\ 8,
        opts \\ []
      )

  def create_optimized_from_raw(data, width, height, color_type, bit_depth, opts)
      when is_binary(data) and is_integer(width) and width > 0 and is_integer(height) and
             height > 0 do
    with {:ok, options} <- Options.new(opts) do
      nif_opts = Options.to_nif_map(options)
      Native.create_optimized_from_raw(data, width, height, color_type, bit_depth, nif_opts)
    end
  end

  def create_optimized_from_raw(data, width, height, _color_type, _bit_depth, _opts) do
    {:error,
     "Invalid parameters for create_optimized_from_raw: data=#{inspect(is_binary(data))}, width=#{inspect(width)}, height=#{inspect(height)}"}
  end

  @doc """
  Same as `create_optimized_from_raw/6`, but returns the binary or raises `Oxipng.Error`.
  """
  @spec create_optimized_from_raw!(
          binary(),
          pos_integer(),
          pos_integer(),
          atom() | tuple(),
          1 | 2 | 4 | 8 | 16,
          keyword() | map() | Options.t()
        ) :: binary()
  def create_optimized_from_raw!(
        data,
        width,
        height,
        color_type \\ :rgba,
        bit_depth \\ 8,
        opts \\ []
      ) do
    case create_optimized_from_raw(data, width, height, color_type, bit_depth, opts) do
      {:ok, png} -> png
      {:error, reason} -> raise Error, message: reason
    end
  end

  @doc """
  Returns the version of the underlying oxipng Rust library.
  """
  @spec version() :: String.t()
  def version do
    Native.version()
  end
end
