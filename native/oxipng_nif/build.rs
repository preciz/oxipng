use std::{env, fs, path::PathBuf};

fn main() {
    println!("cargo:rerun-if-changed=Cargo.lock");
    let lock = fs::read_to_string(
        PathBuf::from(env::var_os("CARGO_MANIFEST_DIR").unwrap()).join("Cargo.lock"),
    )
    .expect("the packaged Cargo.lock must be present");
    // Cargo owns this format. Read the resolved dependency version, not our crate version.
    let package = lock
        .split("[[package]]")
        .find(|package| package.lines().any(|line| line == "name = \"oxipng\""))
        .expect("oxipng must be present in Cargo.lock");
    let version = package
        .lines()
        .find_map(|line| {
            line.strip_prefix("version = \"")
                .and_then(|value| value.strip_suffix('"'))
        })
        .expect("the locked oxipng package must have a version");
    println!("cargo:rustc-env=OXIPNG_VERSION={version}");
}
