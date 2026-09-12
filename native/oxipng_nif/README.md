# Oxipng NIF

The Elixir API uses Rustler to call oxipng on dirty CPU schedulers. PNG inputs
are borrowed from BEAM binaries; raw pixels are copied into the owned buffer
required by `RawImage`. Unchanged PNG results reuse the input binary.

File optimization writes a temporary sibling, syncs it, then atomically replaces
the destination. Existing symbolic links are followed. Replacing an inode means
other hard links keep the previous contents. The destination directory must be
writable. File permissions are retained for existing destinations; `preserve_attrs`
copies input permissions and modification time. New files are private to the
owner on Unix unless input attributes are requested. Access time is not preserved.

Build and check from the project root:

```sh
OXIPNG_BUILD=true mix test --cover
OXIPNG_BUILD=true mix credo --strict
mix format --check-formatted
cd native/oxipng_nif
cargo test --locked
cargo fmt --check
cargo clippy --locked --all-targets -- -D warnings
```

Independent pixel tests use libpng. With its development headers and `pkg-config`
installed, run from the project root:

```sh
cc -O2 test/support/decode_png.c $(pkg-config --cflags --libs libpng) -o /tmp/oxipng-decode
OXIPNG_BUILD=true OXIPNG_TEST_DECODER=/tmp/oxipng-decode mix test --only libpng
```

Source builds require Rust 1.88 or newer and a C compiler. `Cargo.lock` is shipped
with the package, and `build.rs` derives `Oxipng.version/0` from its resolved
oxipng dependency. Update the lockfile intentionally when upgrading dependencies.

The release workflow builds all targets, generates checksums from those exact
archives, and runs the Elixir suite against the Linux precompiled artifact in a
fresh build directory before publishing. It also produces the Hex package with
the generated checksums. See the release instructions in the main README.
