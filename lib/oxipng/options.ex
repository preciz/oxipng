defmodule Oxipng.Options do
  @moduledoc """
  Options for oxipng optimization.

  ## Available Options

    * `:level` - Optimization level from `0` to `6` (default: `2`).
      - `0`: Fewest optimizations (fastest).
      - `1`: Basic optimizations.
      - `2`: Default balance between compression and speed.
      - `3`: Thorough optimization.
      - `4`: High compression.
      - `5`: Very high compression.
      - `6`: Maximum compression (slowest).

    * `:interlace` - Interlacing mode:
      - `nil` or `:keep` (default) - Keep original interlacing.
      - `true` - Force interlacing (Adam7).
      - `false` - Disable interlacing.

    * `:strip` - Metadata stripping:
      - `:none` (default) - Keep all metadata.
      - `:safe` or `true` - Strip all metadata that does not affect display.
      - `:all` - Strip all metadata including color profiles.
      - `{:keep, list}` - Keep only specific chunk names (e.g. `{:keep, ["tEXt", "iTXt"]}`).
      - `{:strip, list}` - Strip specific chunk names (e.g. `{:strip, ["iCCP"]}`).

    * `:optimize_alpha` - Allow transparency color values to be altered to improve
      compression when fully transparent (default: `false`).

    * `:bit_depth_reduction` - Attempt bit depth reduction (default: `true`).

    * `:color_type_reduction` - Attempt color type reduction (default: `true`).

    * `:palette_reduction` - Attempt palette reduction (default: `true`).

    * `:grayscale_reduction` - Attempt grayscale reduction (default: `true`).

    * `:idat_recoding` - Recode IDAT chunks (default: `true`).

    * `:scale_16` - Forcibly reduce 16-bit to 8-bit by scaling (default: `false`).

    * `:fast_evaluation` - Whether to use fast evaluation to pick the best filter
      (default: `nil`, uses preset default).

    * `:force` - Force writing the output even if it is larger than input (default: `false`).

    * `:fix_errors` - Attempt to fix errors when decoding rather than failing (default: `false`).

    * `:timeout` - Maximum optimization time in milliseconds (default: `nil`).

    * `:max_decompressed_size` - Maximum decompressed size of input in bytes (default: `nil`).

    * `:deflater` - DEFLATE algorithm:
      - `{:libdeflater, 0..12}` - Use libdeflater with compression level.
      - `:zopfli` - Use Zopfli with default 15 iterations.
      - `{:zopfli, iterations}` - Use Zopfli with specified iteration count.
      - `{:zopfli, iterations, without_improvement}` - Use Zopfli with iteration limits.

    * `:filters` - List of filter strategies to try:
      - Any combination of `:none`, `:sub`, `:up`, `:average`, `:paeth`,
        `:min_sum`, `:entropy`, `:bigrams`, `:big_ent`, or `{:brute, num_lines, level}`.

    * `:preserve_attrs` - In file optimization, preserve file permissions and timestamps
      (default: `false`).
  """

  defstruct level: 2,
            interlace: nil,
            strip: :none,
            optimize_alpha: false,
            bit_depth_reduction: true,
            color_type_reduction: true,
            palette_reduction: true,
            grayscale_reduction: true,
            idat_recoding: true,
            scale_16: false,
            fast_evaluation: nil,
            force: false,
            fix_errors: false,
            timeout: nil,
            max_decompressed_size: nil,
            deflater: nil,
            filters: nil,
            preserve_attrs: false

  @type level :: 0..6
  @type interlace :: nil | :keep | boolean()
  @type strip_mode ::
          :none
          | :safe
          | :all
          | boolean()
          | {:keep, [String.t() | atom()]}
          | {:strip, [String.t() | atom()]}
  @type deflater_opt ::
          nil
          | :zopfli
          | {:libdeflater, 0..12}
          | {:zopfli, pos_integer()}
          | {:zopfli, pos_integer(), pos_integer()}
  @type filter_opt ::
          :none
          | :sub
          | :up
          | :average
          | :paeth
          | :min_sum
          | :entropy
          | :bigrams
          | :big_ent
          | {:brute, pos_integer(), 1..12}

  @type t :: %__MODULE__{
          level: level(),
          interlace: interlace(),
          strip: strip_mode(),
          optimize_alpha: boolean(),
          bit_depth_reduction: boolean(),
          color_type_reduction: boolean(),
          palette_reduction: boolean(),
          grayscale_reduction: boolean(),
          idat_recoding: boolean(),
          scale_16: boolean(),
          fast_evaluation: boolean() | nil,
          force: boolean(),
          fix_errors: boolean(),
          timeout: pos_integer() | nil,
          max_decompressed_size: pos_integer() | nil,
          deflater: deflater_opt(),
          filters: [filter_opt()] | nil,
          preserve_attrs: boolean()
        }

  @doc """
  Builds and validates an `%Oxipng.Options{}` struct from a keyword list or map.
  """
  @spec new(term()) :: {:ok, t()} | {:error, String.t()}
  def new(%__MODULE__{} = opts), do: validate(opts)

  def new(opts) when is_list(opts) or is_map(opts) do
    struct(__MODULE__, opts)
    |> validate()
  end

  def new(invalid) do
    {:error, "Options must be a keyword list or map, got: #{inspect(invalid)}"}
  end

  @doc """
  Same as `new/1` but raises `ArgumentError` on invalid options.
  """
  @spec new!(term()) :: t()
  def new!(opts) do
    case new(opts) do
      {:ok, validated} -> validated
      {:error, reason} -> raise ArgumentError, reason
    end
  end

  @doc """
  Converts an `%Oxipng.Options{}` struct into a map suitable for the NIF.
  """
  @spec to_nif_map(t()) :: map()
  def to_nif_map(%__MODULE__{} = opts) do
    strip =
      case opts.strip do
        true -> :safe
        false -> :none
        other -> other
      end

    interlace =
      case opts.interlace do
        :keep -> nil
        other -> other
      end

    %{
      level: opts.level,
      interlace: interlace,
      strip: strip,
      optimize_alpha: opts.optimize_alpha,
      bit_depth_reduction: opts.bit_depth_reduction,
      color_type_reduction: opts.color_type_reduction,
      palette_reduction: opts.palette_reduction,
      grayscale_reduction: opts.grayscale_reduction,
      idat_recoding: opts.idat_recoding,
      scale_16: opts.scale_16,
      fast_evaluation: opts.fast_evaluation,
      force: opts.force,
      fix_errors: opts.fix_errors,
      timeout: opts.timeout,
      max_decompressed_size: opts.max_decompressed_size,
      deflater: opts.deflater,
      filters: opts.filters
    }
  end

  defp validate(%__MODULE__{level: level} = opts) do
    cond do
      not (is_integer(level) and level in 0..6) ->
        {:error, "Invalid :level option #{inspect(level)}. Expected an integer from 0 to 6"}

      opts.interlace not in [nil, :keep, true, false] ->
        {:error,
         "Invalid :interlace option #{inspect(opts.interlace)}. Expected nil, :keep, true, or false"}

      not valid_strip?(opts.strip) ->
        {:error,
         "Invalid :strip option #{inspect(opts.strip)}. Expected :none, :safe, :all, true, false, {:keep, [...]}, or {:strip, [...]}"}

      not is_boolean(opts.optimize_alpha) ->
        {:error,
         "Invalid :optimize_alpha option #{inspect(opts.optimize_alpha)}. Expected a boolean"}

      not is_boolean(opts.bit_depth_reduction) ->
        {:error,
         "Invalid :bit_depth_reduction option #{inspect(opts.bit_depth_reduction)}. Expected a boolean"}

      not is_boolean(opts.color_type_reduction) ->
        {:error,
         "Invalid :color_type_reduction option #{inspect(opts.color_type_reduction)}. Expected a boolean"}

      not is_boolean(opts.palette_reduction) ->
        {:error,
         "Invalid :palette_reduction option #{inspect(opts.palette_reduction)}. Expected a boolean"}

      not is_boolean(opts.grayscale_reduction) ->
        {:error,
         "Invalid :grayscale_reduction option #{inspect(opts.grayscale_reduction)}. Expected a boolean"}

      not is_boolean(opts.idat_recoding) ->
        {:error,
         "Invalid :idat_recoding option #{inspect(opts.idat_recoding)}. Expected a boolean"}

      not is_boolean(opts.scale_16) ->
        {:error, "Invalid :scale_16 option #{inspect(opts.scale_16)}. Expected a boolean"}

      opts.fast_evaluation not in [nil, true, false] ->
        {:error,
         "Invalid :fast_evaluation option #{inspect(opts.fast_evaluation)}. Expected nil, true, or false"}

      not is_boolean(opts.force) ->
        {:error, "Invalid :force option #{inspect(opts.force)}. Expected a boolean"}

      not is_boolean(opts.fix_errors) ->
        {:error, "Invalid :fix_errors option #{inspect(opts.fix_errors)}. Expected a boolean"}

      not is_nil(opts.timeout) and (not is_integer(opts.timeout) or opts.timeout <= 0) ->
        {:error,
         "Invalid :timeout option #{inspect(opts.timeout)}. Expected a positive integer in milliseconds or nil"}

      not is_nil(opts.max_decompressed_size) and
          (not is_integer(opts.max_decompressed_size) or opts.max_decompressed_size <= 0) ->
        {:error,
         "Invalid :max_decompressed_size option #{inspect(opts.max_decompressed_size)}. Expected a positive integer in bytes or nil"}

      not valid_deflater?(opts.deflater) ->
        {:error,
         "Invalid :deflater option #{inspect(opts.deflater)}. Expected :zopfli, {:libdeflater, 0..12}, {:zopfli, iterations}, or {:zopfli, iterations, wi}"}

      not valid_filters?(opts.filters) ->
        {:error, "Invalid :filters option #{inspect(opts.filters)}."}

      not is_boolean(opts.preserve_attrs) ->
        {:error,
         "Invalid :preserve_attrs option #{inspect(opts.preserve_attrs)}. Expected a boolean"}

      true ->
        {:ok, opts}
    end
  end

  defp valid_strip?(:none), do: true
  defp valid_strip?(:safe), do: true
  defp valid_strip?(:all), do: true
  defp valid_strip?(b) when is_boolean(b), do: true
  defp valid_strip?({:keep, list}) when is_list(list), do: Enum.all?(list, &valid_chunk_name?/1)
  defp valid_strip?({:strip, list}) when is_list(list), do: Enum.all?(list, &valid_chunk_name?/1)
  defp valid_strip?(_), do: false

  defp valid_chunk_name?(name) when is_binary(name), do: byte_size(name) == 4
  defp valid_chunk_name?(name) when is_atom(name), do: byte_size(Atom.to_string(name)) == 4
  defp valid_chunk_name?(_), do: false

  defp valid_deflater?(nil), do: true
  defp valid_deflater?(:zopfli), do: true
  defp valid_deflater?({:libdeflater, comp}) when is_integer(comp) and comp in 0..12, do: true
  defp valid_deflater?({:zopfli, iters}) when is_integer(iters) and iters > 0, do: true

  defp valid_deflater?({:zopfli, iters, wi})
       when is_integer(iters) and iters > 0 and is_integer(wi) and wi > 0, do: true

  defp valid_deflater?(_), do: false

  defp valid_filters?(nil), do: true

  defp valid_filters?(list) when is_list(list) do
    Enum.all?(list, &valid_filter?/1)
  end

  defp valid_filters?(_), do: false

  defp valid_filter?(f)
       when f in [:none, :sub, :up, :average, :paeth, :min_sum, :entropy, :bigrams, :big_ent],
       do: true

  defp valid_filter?({:brute, lines, lvl})
       when is_integer(lines) and lines > 0 and is_integer(lvl) and lvl in 1..12, do: true

  defp valid_filter?(_), do: false
end
