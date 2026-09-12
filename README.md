# Oxipng

Elixir bindings for [oxipng](https://github.com/oxipng/oxipng), a PNG optimizer written in Rust.

Optimize PNG binaries and files, or encode PNGs from raw pixels. Calls are synchronous and use [Rustler](https://github.com/rusterlium/rustler) NIFs on dirty CPU schedulers. The calling process waits while normal BEAM schedulers remain available.

Compression is lossless by default. `scale_16: true` reduces precision, `optimize_alpha: true` can change hidden RGB values in transparent pixels, and stripping color metadata can affect image appearance.

## Installation

Add the dependency to `mix.exs`:

```elixir
{:oxipng, "~> 0.1.0"}
```

`rustler_precompiled` downloads NIF binaries from GitHub Releases for these platforms:

| Platform | Architectures |
|---|---|
| Linux (glibc) | x86_64, ARM64, ARM32 hard-float |
| Linux (musl) | x86_64, ARM64 |
| macOS | x86_64, ARM64 |
| Windows | x86_64 |

These binaries do not require Rust. To compile from source, also add `{:rustler, "~> 0.38.0"}` to your dependencies, install Rust and a C toolchain, and set this before compiling:

```sh
export OXIPNG_BUILD=true
```

## Usage

### PNG binaries

```elixir
{:ok, optimized} = Oxipng.optimize(png_binary)
{:ok, optimized} = Oxipng.optimize(png_binary, level: 4, strip: :safe)
```

### Files

```elixir
# Write to a separate file
{:ok, stats} = Oxipng.optimize_file("input.png", "output.png", level: 3)

# Optimize in place
{:ok, stats} = Oxipng.optimize_file("photo.png", level: 2)
```

File calls return `{:ok, %{in_bytes: input_size, out_bytes: output_size}}`.

### Raw pixels

```elixir
raw_rgba = <<255, 0, 0, 255, 0, 255, 0, 255>>
{:ok, png} = Oxipng.create_optimized_from_raw(raw_rgba, 2, 1, :rgba, 8)
```

Color types are `:rgba`, `:rgb`, `:grayscale`, `:grayscale_alpha`, and `{:indexed, palette_binary}`. Palettes contain RGBA entries of four bytes each.

Grayscale supports bit depths 1, 2, 4, 8, and 16; indexed images support 1, 2, 4, and 8; other types support 8 and 16. Pack each row into whole bytes for depths below 8. Use big-endian samples for 16-bit data.

Each function also has a `!` variant that returns the result directly or raises `Oxipng.Error`.

## Options

All three functions accept a keyword list, an atom-keyed map, or an `%Oxipng.Options{}` struct.

| Option | Default | Description |
|---|---|---|
| `:level` | `2` | Optimization preset from 0 to 6. |
| `:interlace` | `nil` | `true` requests Adam7 interlacing; `false` requests removal. `nil` or `:keep` preserves it. Set `force: true` to apply changes even without a size improvement. |
| `:strip` | `:none` | Metadata stripping policy; see below. |
| `:optimize_alpha` | `false` | Allow RGB values of fully transparent pixels to change. |
| `:bit_depth_reduction` | `true` | Attempt bit depth reduction. |
| `:color_type_reduction` | `true` | Attempt color type reduction. |
| `:palette_reduction` | `true` | Attempt palette reduction. |
| `:grayscale_reduction` | `true` | Attempt grayscale reduction. |
| `:idat_recoding` | `true` | Recode IDAT chunks. Reductions can require recoding even when this is `false`. |
| `:scale_16` | `false` | Allow lossy 16-bit to 8-bit scaling when bit depth reduction is enabled. |
| `:deflater` | `nil` | Use the preset default, `{:libdeflater, 0..12}`, `:zopfli`, `{:zopfli, iterations}`, or `{:zopfli, iterations, without_improvement}`. |
| `:filters` | `nil` | Use the preset default or a list of filters described below. |
| `:fast_evaluation` | `nil` | Use the preset default, or set `true`/`false` to control fast filter evaluation. |
| `:timeout` | `nil` | Soft budget in milliseconds. Skips further work after the deadline, but does not interrupt running compression. |
| `:max_decompressed_size` | `nil` | Maximum decompressed input IDAT size in bytes. |
| `:force` | `false` | Return or write output even if it is not smaller than the input. |
| `:fix_errors` | `false` | Attempt to recover from decoding errors. |
| `:preserve_attrs` | `false` | For files, preserve permissions and modification time, but not access time. |

Stripping policies:

- `:none` or `false`: disable optional metadata stripping.
- `:safe` or `true`: use oxipng's allowlist (`cICP`, `iCCP`, `sRGB`, `pHYs`, `acTL`, `fcTL`, `fdAT`). This removes `gAMA` and `cHRM`, which can affect appearance.
- `:all`: strip all optional metadata, including color profiles.
- `{:keep, chunks}`: keep only the specified optional chunks.
- `{:strip, chunks}`: strip the specified chunks.

Chunk names are four-byte strings or atoms, such as `"tEXt"` or `:tEXt`.

Filters are `:none`, `:sub`, `:up`, `:average`, `:paeth`, `:min_sum`, `:entropy`, `:bigrams`, `:big_ent`, or `{:brute, lines, level}`. Brute filtering takes a positive line count and a compression level from 1 to 12.

## License

[MIT](LICENSE).
