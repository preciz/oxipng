defmodule Oxipng.Options do
  @moduledoc """
  Options for oxipng optimization.

  ## Available Options

    * `:level` - Optimization preset from `0` to `6` (default: `2`).

    * `:interlace` - Interlacing mode:
      - `nil` or `:keep` (default) - Keep original interlacing.
      - `true` - Request interlacing (Adam7).
      - `false` - Request removal of interlacing.

      Changes can be skipped if output is not smaller. Set `force: true` to apply
      the requested interlacing even without a size improvement.

    * `:strip` - Metadata stripping:
      - `:none` or `false` (default) - Disable optional metadata stripping.
      - `:safe` or `true` - Use oxipng's metadata allowlist: `cICP`, `iCCP`, `sRGB`,
        `pHYs`, `acTL`, `fcTL`, and `fdAT`. This removes `gAMA` and `cHRM` and can
        affect image appearance.
      - `:all` - Strip all optional metadata including color profiles.
      - `{:keep, list}` - Keep only specific chunk names (e.g. `{:keep, ["tEXt", "iTXt"]}`).
      - `{:strip, list}` - Strip specific chunk names (e.g. `{:strip, ["iCCP"]}`).

    * `:optimize_alpha` - Allow transparency color values to be altered to improve
      compression when fully transparent (default: `false`).

    * `:bit_depth_reduction` - Attempt bit depth reduction (default: `true`).

    * `:color_type_reduction` - Attempt color type reduction (default: `true`).

    * `:palette_reduction` - Attempt palette reduction (default: `true`).

    * `:grayscale_reduction` - Attempt grayscale reduction (default: `true`).

    * `:idat_recoding` - Recode IDAT chunks (default: `true`). Reductions can require
      recoding even when this is `false`.

    * `:scale_16` - Allow lossy scaling from 16-bit to 8-bit when bit depth reduction
      is enabled (default: `false`).

    * `:fast_evaluation` - Whether to use fast evaluation to pick the best filter
      (default: `nil`, uses preset default).

    * `:force` - Return or write output even if it is not smaller than input
      (default: `false`).

    * `:fix_errors` - Attempt to fix errors when decoding rather than failing (default: `false`).

    * `:timeout` - Soft optimization budget in milliseconds (default: `nil`).
      Skips further work after the deadline; does not interrupt compression already
      running, so the call can take longer.

    * `:max_decompressed_size` - Maximum decompressed size of input in bytes (default: `nil`).

    * `:deflater` - DEFLATE algorithm:
      - `{:libdeflater, 0..12}` - Use libdeflater with compression level.
      - `:zopfli` - Use Zopfli with default 15 iterations.
      - `{:zopfli, iterations}` - Use Zopfli with specified iteration count.
      - `{:zopfli, iterations, without_improvement}` - Use Zopfli with iteration limits.

    * `:filters` - List of filter strategies to try:
      - Any combination of `:none`, `:sub`, `:up`, `:average`, `:paeth`,
        `:min_sum`, `:entropy`, `:bigrams`, `:big_ent`, or `{:brute, num_lines, level}`.

    * `:preserve_attrs` - In file optimization, preserve file permissions and
      modification time, but not access time (default: `false`).
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
  def new(%__MODULE__{} = opts), do: new(Map.from_struct(opts))

  def new(opts) when is_list(opts) do
    if Keyword.keyword?(opts), do: new(Map.new(opts)), else: invalid_options(opts)
  end

  def new(opts) when is_map(opts) do
    unknown = Map.keys(opts) -- Map.keys(Map.from_struct(%__MODULE__{}))

    if unknown == [] do
      validate(struct!(__MODULE__, opts))
    else
      {:error, "Unknown options: #{inspect(Enum.sort(unknown))}"}
    end
  end

  def new(invalid), do: invalid_options(invalid)

  defp invalid_options(invalid) do
    {:error, "Options must be a keyword list or map, got: #{inspect(invalid)}"}
  end

  @doc """
  Same as `new/1` but raises `ArgumentError` on invalid options.
  """
  @spec new!(term()) :: t()
  def new!(opts) when is_list(opts) or is_map(opts) do
    case new(opts) do
      {:ok, validated} -> validated
      {:error, reason} -> raise ArgumentError, reason
    end
  end

  def new!(invalid) do
    raise ArgumentError, "Options must be a keyword list or map, got: #{inspect(invalid)}"
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

  defp validate(%__MODULE__{} = opts) do
    with :ok <- validate_level(opts.level),
         :ok <- validate_interlace(opts.interlace),
         :ok <- validate_strip(opts.strip),
         :ok <- validate_flags(opts),
         :ok <- validate_sizes(opts),
         :ok <- validate_deflater(opts.deflater),
         :ok <- validate_filters(opts.filters) do
      {:ok, opts}
    end
  end

  defp validate_level(level) do
    if is_integer(level) and level in 0..6 do
      :ok
    else
      {:error, "Invalid :level option #{inspect(level)}. Expected an integer from 0 to 6"}
    end
  end

  defp validate_interlace(interlace) do
    if interlace in [nil, :keep, true, false] do
      :ok
    else
      {:error,
       "Invalid :interlace option #{inspect(interlace)}. Expected nil, :keep, true, or false"}
    end
  end

  defp validate_strip(strip) do
    if valid_strip?(strip) do
      :ok
    else
      {:error,
       "Invalid :strip option #{inspect(strip)}. Expected :none, :safe, :all, true, false, {:keep, [...]}, or {:strip, [...]}"}
    end
  end

  @boolean_options ~w(optimize_alpha bit_depth_reduction color_type_reduction
    palette_reduction grayscale_reduction idat_recoding scale_16 force fix_errors preserve_attrs)a
  @max_u64 18_446_744_073_709_551_615

  defp validate_flags(%{fast_evaluation: fast_evaluation} = opts) do
    case Enum.find(@boolean_options, &(not is_boolean(Map.fetch!(opts, &1)))) do
      nil ->
        if is_nil(fast_evaluation) or is_boolean(fast_evaluation) do
          :ok
        else
          {:error,
           "Invalid :fast_evaluation option #{inspect(fast_evaluation)}. Expected nil or a boolean"}
        end

      key ->
        {:error,
         "Invalid #{inspect(key)} option #{inspect(Map.fetch!(opts, key))}. Expected a boolean"}
    end
  end

  defp validate_sizes(opts) do
    cond do
      not is_nil(opts.timeout) and
          (not is_integer(opts.timeout) or opts.timeout not in 1..@max_u64) ->
        {:error,
         "Invalid :timeout option #{inspect(opts.timeout)}. Expected an integer from 1 to #{@max_u64} in milliseconds or nil"}

      not is_nil(opts.max_decompressed_size) and
          (not is_integer(opts.max_decompressed_size) or
             opts.max_decompressed_size not in 1..@max_u64) ->
        {:error,
         "Invalid :max_decompressed_size option #{inspect(opts.max_decompressed_size)}. Expected an integer from 1 to #{@max_u64} in bytes or nil"}

      true ->
        :ok
    end
  end

  defp validate_deflater(deflater) do
    if valid_deflater?(deflater) do
      :ok
    else
      {:error,
       "Invalid :deflater option #{inspect(deflater)}. Expected :zopfli, {:libdeflater, 0..12}, {:zopfli, iterations}, or {:zopfli, iterations, wi}"}
    end
  end

  defp validate_filters(filters) do
    if valid_filters?(filters) do
      :ok
    else
      {:error, "Invalid :filters option #{inspect(filters)}."}
    end
  end

  defp valid_strip?(:none), do: true
  defp valid_strip?(:safe), do: true
  defp valid_strip?(:all), do: true
  defp valid_strip?(b) when is_boolean(b), do: true
  defp valid_strip?({:keep, list}) when is_list(list), do: valid_list?(list, &valid_chunk_name?/1)

  defp valid_strip?({:strip, list}) when is_list(list),
    do: valid_list?(list, &valid_chunk_name?/1)

  defp valid_strip?(_), do: false

  defp valid_chunk_name?(name) when is_binary(name), do: byte_size(name) == 4
  defp valid_chunk_name?(name) when is_atom(name), do: byte_size(Atom.to_string(name)) == 4
  defp valid_chunk_name?(_), do: false

  defp valid_deflater?(nil), do: true
  defp valid_deflater?(:zopfli), do: true
  defp valid_deflater?({:libdeflater, comp}) when is_integer(comp) and comp in 0..12, do: true
  defp valid_deflater?({:zopfli, iters}) when is_integer(iters) and iters in 1..@max_u64, do: true

  defp valid_deflater?({:zopfli, iters, wi})
       when is_integer(iters) and iters in 1..@max_u64 and is_integer(wi) and wi in 1..@max_u64,
       do: true

  defp valid_deflater?(_), do: false

  defp valid_filters?(nil), do: true

  defp valid_filters?([_ | _] = list) do
    valid_list?(list, &valid_filter?/1)
  end

  defp valid_filters?(_), do: false

  defp valid_filter?(f)
       when f in [:none, :sub, :up, :average, :paeth, :min_sum, :entropy, :bigrams, :big_ent],
       do: true

  defp valid_filter?({:brute, lines, lvl})
       when is_integer(lines) and lines in 1..@max_u64 and is_integer(lvl) and lvl in 1..12,
       do: true

  defp valid_filter?(_), do: false

  defp valid_list?([], _validator), do: true

  defp valid_list?([head | tail], validator),
    do: validator.(head) and valid_list?(tail, validator)

  defp valid_list?(_, _validator), do: false
end
