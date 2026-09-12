# Oxipng

[![Hex.pm](https://img.shields.io/hexpm/v/oxipng.svg)](https://hex.pm/packages/oxipng)
[![Documentation](https://img.shields.io/badge/docs-hexpm-blue.svg)](https://hexdocs.pm/oxipng)
[![License](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)

An Elixir wrapper for [oxipng](https://github.com/oxipng/oxipng), a multithreaded lossless PNG compression optimizer written in Rust.

Binding is implemented using [Rustler](https://github.com/rusterlium/rustler). Heavy compression work runs asynchronously on Erlang's **Dirty CPU schedulers**, preventing BEAM scheduler blocking.

## Installation

Add `oxipng` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:oxipng, "~> 0.1.0"}
  ]
end
```

Rust (Cargo) is required to compile the native NIF during build time.

## Features

- 🚀 **Lossless in-memory compression**: Optimize PNG binaries directly in memory (`Oxipng.optimize/2`).
- 📁 **File compression**: In-place or copy optimization of PNG files on disk (`Oxipng.optimize_file/3`).
- 🎨 **Raw pixel encoding**: Encode and optimize directly from raw pixel buffers (RGBA, RGB, Grayscale, Indexed) without an intermediate PNG encoder (`Oxipng.create_optimized_from_raw/6`).
- ⚡ **Dirty CPU Schedulers**: Non-blocking integration with Erlang/Elixir runtime.
- 🛠️ **Full options support**: Configurable optimization levels (0-6), metadata stripping, interlacing, custom filters, Zopfli DEFLATE algorithm, and reductions.

## Usage

### In-Memory Optimization

```elixir
# Basic optimization with default level (preset 2)
{:ok, optimized_png} = Oxipng.optimize(png_binary)

# High compression with metadata stripped
{:ok, optimized_png} = Oxipng.optimize(png_binary, level: 4, strip: :safe)

# Bang variant (raises Oxipng.Error on failure)
optimized_png = Oxipng.optimize!(png_binary, level: 6)
```

### File Optimization

```elixir
# Optimize a file to a new destination
{:ok, stats} = Oxipng.optimize_file("input.png", "output.png", level: 3)
#=> {:ok, %{in_bytes: 40960, out_bytes: 28412}}

# Optimize a file in-place
{:ok, stats} = Oxipng.optimize_file("photo.png", level: 2)

# Bang variant
stats = Oxipng.optimize_file!("input.png", "output.png")
```

### Direct Raw Pixel Encoding

```elixir
# Create an optimized PNG directly from raw RGBA pixel data
raw_rgba = <<255, 0, 0, 255, 0, 255, 0, 255, ...>>
{:ok, png_binary} = Oxipng.create_optimized_from_raw(raw_rgba, width, height, :rgba, 8)
```

Supported color types: `:rgba`, `:rgb`, `:grayscale`, `:grayscale_alpha`, and `{:indexed, palette_binary}`.

## Options

All optimization functions accept options as a keyword list, map, or `%Oxipng.Options{}` struct:

| Option | Type | Default | Description |
|---|---|---|---|
| `:level` | `0..6` | `2` | Optimization preset level (0 = fastest, 6 = maximum compression). |
| `:interlace` | `boolean() \| nil \| :keep` | `nil` | `true` to enable Adam7 interlacing, `false` to disable, `nil`/`:keep` to preserve original. |
| `:strip` | `:none \| :safe \| :all \| boolean() \| {:keep, list} \| {:strip, list}` | `:none` | Metadata chunks to strip. `:safe` strips non-display metadata; `:all` strips all metadata including color profiles. |
| `:optimize_alpha` | `boolean()` | `false` | Allow transparency color values to be altered to improve compression. |
| `:bit_depth_reduction` | `boolean()` | `true` | Attempt bit depth reduction. |
| `:color_type_reduction` | `boolean()` | `true` | Attempt color type reduction. |
| `:palette_reduction` | `boolean()` | `true` | Attempt palette reduction. |
| `:grayscale_reduction` | `boolean()` | `true` | Attempt grayscale reduction. |
| `:idat_recoding` | `boolean()` | `true` | Recode IDAT chunks. |
| `:scale_16` | `boolean()` | `false` | Forcibly reduce 16-bit to 8-bit by scaling. |
| `:deflater` | `tuple() \| atom()` | `nil` | `{:libdeflater, 0..12}`, `:zopfli`, or `{:zopfli, iterations}`. |
| `:filters` | `[atom() \| tuple()]` | `nil` | Row filtering strategies (`:none`, `:sub`, `:up`, `:average`, `:paeth`, `:min_sum`, `:entropy`, `:bigrams`, `:big_ent`, `{:brute, lines, level}`). |
| `:timeout` | `pos_integer() \| nil` | `nil` | Max optimization duration in milliseconds. |
| `:max_decompressed_size` | `pos_integer() \| nil` | `nil` | Maximum decompressed IDAT size in bytes. |
| `:force` | `boolean()` | `false` | Force writing output even if larger than input. |
| `:fix_errors` | `boolean()` | `false` | Attempt to fix decoding errors rather than aborting. |
| `:preserve_attrs` | `boolean()` | `false` | Preserve file timestamps and permissions when optimizing files. |

## License

MIT License. See [LICENSE](LICENSE) for details.
