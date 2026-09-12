use std::num::NonZeroU64;
use std::path::PathBuf;
use std::time::Duration;

use indexmap::IndexSet;
use oxipng::{
    Deflater, FilterStrategy, InFile, Options, OutFile, RawImage, RowFilter, StripChunks,
    ZopfliOptions,
};
use rustler::{types::atom, Binary, Env, OwnedBinary, Term};

mod atoms {
    rustler::atoms! {
        ok,
        error,
        nil,

        // Options keys
        level,
        fix_errors,
        force,
        filters,
        interlace,
        optimize_alpha,
        bit_depth_reduction,
        color_type_reduction,
        palette_reduction,
        grayscale_reduction,
        idat_recoding,
        scale_16,
        strip,
        deflater,
        fast_evaluation,
        timeout,
        max_decompressed_size,

        // Strip options
        none,
        safe,
        all,
        keep,

        // Row Filters
        sub,
        up,
        average,
        paeth,

        // Filter Strategies
        min_sum,
        entropy,
        bigrams,
        big_ent,
        brute,

        // Deflater options
        libdeflater,
        zopfli,

        // Color types
        rgba,
        rgb,
        grayscale,
        gray,
        grayscale_alpha,
        gray_alpha,
        indexed,
    }
}

fn parse_chunk_name(term: Term) -> Result<[u8; 4], String> {
    let bytes = if let Ok(s) = term.decode::<String>() {
        s.into_bytes()
    } else if let Ok(a) = term.decode::<rustler::Atom>() {
        let atom_str = format!("{a:?}");
        let clean = atom_str.trim_start_matches(':');
        clean.as_bytes().to_vec()
    } else {
        return Err("Chunk name must be a 4-byte string or atom".to_string());
    };

    if bytes.len() != 4 {
        return Err(format!(
            "Chunk name must be exactly 4 bytes, got '{}'",
            String::from_utf8_lossy(&bytes)
        ));
    }

    let mut arr = [0u8; 4];
    arr.copy_from_slice(&bytes[..4]);
    Ok(arr)
}

fn parse_chunk_names(term: Term) -> Result<IndexSet<[u8; 4]>, String> {
    let list: Vec<Term> = term
        .decode()
        .map_err(|_| "Expected a list of 4-byte chunk names".to_string())?;
    let mut set = IndexSet::new();
    for item in list {
        set.insert(parse_chunk_name(item)?);
    }
    Ok(set)
}

fn parse_strip(term: Term) -> Result<StripChunks, String> {
    if let Ok(b) = term.decode::<bool>() {
        return Ok(if b {
            StripChunks::Safe
        } else {
            StripChunks::None
        });
    }

    if let Ok(a) = term.decode::<rustler::Atom>() {
        if a == atoms::none() {
            return Ok(StripChunks::None);
        } else if a == atoms::safe() {
            return Ok(StripChunks::Safe);
        } else if a == atoms::all() {
            return Ok(StripChunks::All);
        }
    }

    if let Ok((tag, chunks_term)) = term.decode::<(rustler::Atom, Term)>() {
        if tag == atoms::keep() {
            let names = parse_chunk_names(chunks_term)?;
            return Ok(StripChunks::Keep(names));
        } else if tag == atoms::strip() {
            let names = parse_chunk_names(chunks_term)?;
            return Ok(StripChunks::Strip(names));
        }
    }

    Err("Invalid strip option. Expected :none, :safe, :all, {:keep, [...]}, {:strip, [...]}, or boolean".to_string())
}

fn parse_filter_strategy(term: Term) -> Result<FilterStrategy, String> {
    if let Ok(a) = term.decode::<rustler::Atom>() {
        if a == atoms::none() {
            return Ok(FilterStrategy::Basic(RowFilter::None));
        } else if a == atoms::sub() {
            return Ok(FilterStrategy::Basic(RowFilter::Sub));
        } else if a == atoms::up() {
            return Ok(FilterStrategy::Basic(RowFilter::Up));
        } else if a == atoms::average() {
            return Ok(FilterStrategy::Basic(RowFilter::Average));
        } else if a == atoms::paeth() {
            return Ok(FilterStrategy::Basic(RowFilter::Paeth));
        } else if a == atoms::min_sum() {
            return Ok(FilterStrategy::MinSum);
        } else if a == atoms::entropy() {
            return Ok(FilterStrategy::Entropy);
        } else if a == atoms::bigrams() {
            return Ok(FilterStrategy::Bigrams);
        } else if a == atoms::big_ent() {
            return Ok(FilterStrategy::BigEnt);
        }
    }

    if let Ok((tag, num_lines, level)) = term.decode::<(rustler::Atom, usize, u8)>() {
        if tag == atoms::brute() {
            if !(1..=12).contains(&level) {
                return Err(format!(
                    "Brute filter level must be between 1 and 12, got {level}"
                ));
            }
            return Ok(FilterStrategy::Brute { num_lines, level });
        }
    }

    Err("Invalid filter strategy. Expected :none, :sub, :up, :average, :paeth, :min_sum, :entropy, :bigrams, :big_ent, or {:brute, num_lines, level}".to_string())
}

fn parse_filters(term: Term) -> Result<IndexSet<FilterStrategy>, String> {
    let list: Vec<Term> = term
        .decode()
        .map_err(|_| "Expected a list of filter strategies".to_string())?;
    let mut set = IndexSet::new();
    for item in list {
        set.insert(parse_filter_strategy(item)?);
    }
    if set.is_empty() {
        return Err("At least one filter is required".into());
    }
    Ok(set)
}

fn parse_deflater(term: Term) -> Result<Deflater, String> {
    if let Ok(a) = term.decode::<rustler::Atom>() {
        if a == atoms::zopfli() {
            return Ok(Deflater::Zopfli(ZopfliOptions::default()));
        }
    }

    if let Ok((tag, value)) = term.decode::<(rustler::Atom, u64)>() {
        if tag == atoms::libdeflater() {
            if value > 12 {
                return Err(format!(
                    "libdeflater compression level must be between 0 and 12, got {value}"
                ));
            }
            return Ok(Deflater::Libdeflater {
                compression: value as u8,
            });
        } else if tag == atoms::zopfli() {
            let iterations = NonZeroU64::new(value)
                .ok_or_else(|| "Zopfli iteration count must be greater than 0".to_string())?;
            return Ok(Deflater::Zopfli(ZopfliOptions {
                iteration_count: iterations,
                ..Default::default()
            }));
        }
    }

    if let Ok((tag, iterations, iterations_without_improvement)) =
        term.decode::<(rustler::Atom, u64, u64)>()
    {
        if tag == atoms::zopfli() {
            let iter = NonZeroU64::new(iterations)
                .ok_or_else(|| "Zopfli iteration count must be greater than 0".to_string())?;
            let iter_wi =
                NonZeroU64::new(iterations_without_improvement).unwrap_or(NonZeroU64::MAX);
            return Ok(Deflater::Zopfli(ZopfliOptions {
                iteration_count: iter,
                iterations_without_improvement: iter_wi,
                ..Default::default()
            }));
        }
    }

    Err("Invalid deflater. Expected :zopfli, {:libdeflater, 0..12}, {:zopfli, iterations}, or {:zopfli, iterations, without_improvement}".to_string())
}

fn get_opt<'a, T: rustler::Decoder<'a>>(
    term: Term<'a>,
    key: rustler::Atom,
) -> Result<Option<T>, String> {
    let key_term = key.to_term(term.get_env());
    match term.map_get(key_term) {
        Ok(val) => {
            if val == atom::nil().to_term(term.get_env()) {
                Ok(None)
            } else {
                val.decode::<T>()
                    .map(Some)
                    .map_err(|_| format!("Invalid value for option :{key:?}"))
            }
        }
        Err(_) => Ok(None),
    }
}

fn parse_options<'a>(opts_term: Term<'a>) -> Result<Options, String> {
    let env = opts_term.get_env();
    if opts_term == atom::nil().to_term(env) {
        return Ok(Options::from_preset(2));
    }

    let level = get_opt::<u8>(opts_term, atoms::level())?;
    let mut opts = if let Some(lvl) = level {
        if lvl > 6 {
            return Err(format!(
                "Optimization level must be between 0 and 6, got {lvl}"
            ));
        }
        Options::from_preset(lvl)
    } else {
        Options::from_preset(2)
    };

    if let Some(fix) = get_opt::<bool>(opts_term, atoms::fix_errors())? {
        opts.fix_errors = fix;
    }

    if let Some(force) = get_opt::<bool>(opts_term, atoms::force())? {
        opts.force = force;
    }

    if let Some(alpha) = get_opt::<bool>(opts_term, atoms::optimize_alpha())? {
        opts.optimize_alpha = alpha;
    }

    if let Some(depth) = get_opt::<bool>(opts_term, atoms::bit_depth_reduction())? {
        opts.bit_depth_reduction = depth;
    }

    if let Some(color) = get_opt::<bool>(opts_term, atoms::color_type_reduction())? {
        opts.color_type_reduction = color;
    }

    if let Some(pal) = get_opt::<bool>(opts_term, atoms::palette_reduction())? {
        opts.palette_reduction = pal;
    }

    if let Some(gray) = get_opt::<bool>(opts_term, atoms::grayscale_reduction())? {
        opts.grayscale_reduction = gray;
    }

    if let Some(recoding) = get_opt::<bool>(opts_term, atoms::idat_recoding())? {
        opts.idat_recoding = recoding;
    }

    if let Some(scale) = get_opt::<bool>(opts_term, atoms::scale_16())? {
        opts.scale_16 = scale;
    }

    if let Some(fast) = get_opt::<bool>(opts_term, atoms::fast_evaluation())? {
        opts.fast_evaluation = fast;
    }

    if let Ok(interlace_term) = opts_term.map_get(atoms::interlace().to_term(env)) {
        if interlace_term == atom::nil().to_term(env)
            || interlace_term == atoms::none().to_term(env)
        {
            opts.interlace = None;
        } else if let Ok(b) = interlace_term.decode::<bool>() {
            opts.interlace = Some(b);
        } else {
            return Err(
                "Invalid interlace option. Expected nil, :none, true, or false".to_string(),
            );
        }
    }

    if let Ok(strip_term) = opts_term.map_get(atoms::strip().to_term(env)) {
        if strip_term != atom::nil().to_term(env) {
            opts.strip = parse_strip(strip_term)?;
        }
    }

    if let Ok(filters_term) = opts_term.map_get(atoms::filters().to_term(env)) {
        if filters_term != atom::nil().to_term(env) {
            opts.filters = parse_filters(filters_term)?;
        }
    }

    if let Ok(deflater_term) = opts_term.map_get(atoms::deflater().to_term(env)) {
        if deflater_term != atom::nil().to_term(env) {
            opts.deflater = parse_deflater(deflater_term)?;
        }
    }

    if let Some(timeout_ms) = get_opt::<u64>(opts_term, atoms::timeout())? {
        opts.timeout = Some(Duration::from_millis(timeout_ms));
    }

    if let Some(max_size) = get_opt::<usize>(opts_term, atoms::max_decompressed_size())? {
        opts.max_decompressed_size = Some(max_size);
    }

    Ok(opts)
}

fn parse_color_type(term: Term) -> Result<oxipng::ColorType, String> {
    if let Ok(a) = term.decode::<rustler::Atom>() {
        if a == atoms::rgba() {
            return Ok(oxipng::ColorType::RGBA);
        } else if a == atoms::rgb() {
            return Ok(oxipng::ColorType::RGB {
                transparent_color: None,
            });
        } else if a == atoms::grayscale() || a == atoms::gray() {
            return Ok(oxipng::ColorType::Grayscale {
                transparent_shade: None,
            });
        } else if a == atoms::grayscale_alpha() || a == atoms::gray_alpha() {
            return Ok(oxipng::ColorType::GrayscaleAlpha);
        }
    }

    if let Ok((tag, palette_bytes)) = term.decode::<(rustler::Atom, Binary)>() {
        if tag == atoms::indexed() {
            let slice = palette_bytes.as_slice();
            if slice.len() % 4 != 0 {
                return Err("Indexed palette data must be a multiple of 4 bytes (RGBA)".to_string());
            }
            if slice.is_empty() || slice.len() > 256 * 4 {
                return Err("Indexed palettes must contain between 1 and 256 RGBA entries".into());
            }
            let palette: Vec<rgb::RGBA8> = slice
                .as_chunks::<4>()
                .0
                .iter()
                .map(|c| rgb::RGBA8::new(c[0], c[1], c[2], c[3]))
                .collect();
            return Ok(oxipng::ColorType::Indexed { palette });
        }
    }

    Err("Invalid color type. Expected :rgba, :rgb, :grayscale, :grayscale_alpha, or {:indexed, palette_binary}".to_string())
}

fn parse_bit_depth(depth: u8) -> Result<oxipng::BitDepth, String> {
    match depth {
        1 => Ok(oxipng::BitDepth::One),
        2 => Ok(oxipng::BitDepth::Two),
        4 => Ok(oxipng::BitDepth::Four),
        8 => Ok(oxipng::BitDepth::Eight),
        16 => Ok(oxipng::BitDepth::Sixteen),
        _ => Err(format!(
            "Invalid bit depth: {depth}. Expected 1, 2, 4, 8, or 16"
        )),
    }
}

#[rustler::nif(schedule = "DirtyCpu")]
fn optimize<'a>(env: Env<'a>, data: Binary<'a>, opts_term: Term<'a>) -> Result<Binary<'a>, String> {
    let opts = parse_options(opts_term)?;
    let optimized =
        oxipng::optimize_from_memory(data.as_slice(), &opts).map_err(|e| e.to_string())?;

    // With force disabled, oxipng returns the original bytes when it cannot shrink them.
    if !opts.force && optimized.len() >= data.len() {
        return Ok(data);
    }
    output_binary(env, &optimized)
}

fn output_binary<'a>(env: Env<'a>, optimized: &[u8]) -> Result<Binary<'a>, String> {
    let mut owned = OwnedBinary::new(optimized.len())
        .ok_or_else(|| "Failed to allocate memory for optimized image".to_string())?;
    owned.as_mut_slice().copy_from_slice(optimized);
    Ok(owned.release(env))
}

#[rustler::nif(schedule = "DirtyCpu")]
fn optimize_file(
    in_path: String,
    out_path: Option<String>,
    preserve_attrs: bool,
    opts_term: Term<'_>,
) -> Result<(usize, usize), String> {
    let opts = parse_options(opts_term)?;
    let input = InFile::Path(PathBuf::from(&in_path));
    let output = match out_path {
        Some(ref p) if !p.is_empty() => OutFile::Path {
            path: Some(PathBuf::from(p)),
            preserve_attrs,
        },
        _ => OutFile::Path {
            path: None,
            preserve_attrs,
        },
    };

    let result = oxipng::optimize(&input, &output, &opts).map_err(|e| e.to_string())?;

    Ok(result)
}

#[rustler::nif(schedule = "DirtyCpu")]
fn create_optimized_from_raw<'a>(
    env: Env<'a>,
    data: Binary<'a>,
    width: u32,
    height: u32,
    color_type_term: Term<'a>,
    bit_depth: u8,
    opts_term: Term<'a>,
) -> Result<Binary<'a>, String> {
    let opts = parse_options(opts_term)?;
    let color_type = parse_color_type(color_type_term)?;
    let depth = parse_bit_depth(bit_depth)?;
    validate_raw(data.as_slice(), width, height, &color_type, bit_depth)?;

    let raw_image = RawImage::new(width, height, color_type, depth, data.as_slice().to_vec())
        .map_err(|e| e.to_string())?;

    let optimized = raw_image
        .create_optimized_png(&opts)
        .map_err(|e| e.to_string())?;

    output_binary(env, &optimized)
}

fn validate_raw(
    data: &[u8],
    width: u32,
    height: u32,
    color: &oxipng::ColorType,
    depth: u8,
) -> Result<(), String> {
    if width == 0 || height == 0 || width > i32::MAX as u32 || height > i32::MAX as u32 {
        return Err("Image dimensions must be between 1 and 2147483647".into());
    }
    let valid_depth = match color {
        oxipng::ColorType::Grayscale { .. } => true,
        oxipng::ColorType::Indexed { palette } => depth <= 8 && palette.len() <= (1 << depth),
        _ => depth >= 8,
    };
    if !valid_depth {
        return Err("Invalid bit depth for the color type or palette size".into());
    }
    let channels = match color {
        oxipng::ColorType::RGBA => 4,
        oxipng::ColorType::RGB { .. } => 3,
        oxipng::ColorType::GrayscaleAlpha => 2,
        _ => 1,
    };
    let row_bytes = (width as usize)
        .checked_mul(channels)
        .and_then(|n| n.checked_mul(depth as usize))
        .and_then(|n| n.checked_add(7))
        .map(|n| n / 8)
        .ok_or("Image row size exceeds the supported range")?;
    let expected = row_bytes
        .checked_mul(height as usize)
        .ok_or("Image size exceeds the supported range")?;
    if data.len() != expected {
        return Err(format!(
            "Data length {} does not match the expected length {expected}",
            data.len()
        ));
    }
    if let oxipng::ColorType::Indexed { palette } = color {
        let mask = (1u16 << depth) - 1;
        for row in data.chunks_exact(row_bytes) {
            for x in 0..width as usize {
                let bit = x * depth as usize;
                let index = (row[bit / 8] >> (8 - depth as usize - bit % 8)) as u16 & mask;
                if index as usize >= palette.len() {
                    return Err(format!(
                        "Pixel index {index} is outside the {}-entry palette",
                        palette.len()
                    ));
                }
            }
        }
    }
    Ok(())
}

#[rustler::nif]
fn version() -> &'static str {
    "10.2.1"
}

rustler::init!("Elixir.Oxipng.Native");
