use std::fs::{self, File, Metadata};
use std::io::{self, Read, Write};
use std::path::Path;

use oxipng::Options;

pub fn optimize(
    input: &Path,
    output: Option<&Path>,
    preserve_attrs: bool,
    opts: &Options,
) -> Result<(usize, usize), String> {
    if input.as_os_str().is_empty() || output.is_some_and(|p| p.as_os_str().is_empty()) {
        return Err("Input and output paths must not be empty".into());
    }
    optimize_file(input, output, preserve_attrs, opts).map_err(|e| e.to_string())
}

fn optimize_file(
    input: &Path,
    output: Option<&Path>,
    preserve_attrs: bool,
    opts: &Options,
) -> Result<(usize, usize), Box<dyn std::error::Error>> {
    let input = fs::canonicalize(input)?;
    let output = output.unwrap_or(&input);
    // Follow existing symbolic links, preserving the links when replacing their targets.
    let destination = match fs::symlink_metadata(output) {
        Ok(_) => fs::canonicalize(output)?,
        Err(e) if e.kind() == io::ErrorKind::NotFound => output.to_path_buf(),
        Err(e) => return Err(e.into()),
    };
    let mut source = File::open(&input)?;
    let metadata = source.metadata()?;
    if !metadata.is_file() {
        return Err("Input must be a regular file".into());
    }
    let mut data = Vec::new();
    source.read_to_end(&mut data)?;
    drop(source);
    let optimized = oxipng::optimize_from_memory(&data, opts)?;
    let sizes = (data.len(), optimized.len());
    if destination == input && !opts.force && optimized.len() >= data.len() {
        return Ok(sizes);
    }

    let attrs = if preserve_attrs {
        Some(metadata)
    } else {
        match fs::metadata(&destination) {
            Ok(metadata) => Some(metadata),
            Err(e) if e.kind() == io::ErrorKind::NotFound => None,
            Err(e) => return Err(e.into()),
        }
    };
    replace_file(&destination, attrs.as_ref(), preserve_attrs, |file| {
        file.write_all(&optimized)
    })?;
    Ok(sizes)
}

fn replace_file(
    destination: &Path,
    attrs: Option<&Metadata>,
    preserve_modified: bool,
    write: impl FnOnce(&mut File) -> io::Result<()>,
) -> io::Result<()> {
    let parent = destination
        .parent()
        .filter(|p| !p.as_os_str().is_empty())
        .unwrap_or(Path::new("."));
    // Create a normal file so renaming on Windows retains its attributes.
    // NamedTempFile::persist would clear the read-only attribute there.
    let mut temporary = tempfile::Builder::new()
        .prefix(".oxipng-")
        .make_in(parent, |path| {
            let mut options = File::options();
            options.read(true).write(true).create_new(true);
            #[cfg(unix)]
            {
                use std::os::unix::fs::OpenOptionsExt;
                options.mode(0o600);
            }
            options.open(path)
        })?;
    write(temporary.as_file_mut())?;
    if let Some(attrs) = attrs {
        temporary.as_file().set_permissions(attrs.permissions())?;
        if preserve_modified {
            temporary.as_file().set_modified(attrs.modified()?)?;
        }
    }
    temporary.as_file().sync_all()?;
    fs::rename(temporary.path(), destination).inspect_err(|_| {
        // Windows cannot delete a read-only temporary file during cleanup.
        #[cfg(windows)]
        if let Ok(metadata) = temporary.as_file().metadata() {
            let mut permissions = metadata.permissions();
            permissions.set_readonly(false);
            let _ = temporary.as_file().set_permissions(permissions);
        }
    })?;
    temporary.disable_cleanup(true);
    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn failed_write_keeps_original_and_removes_temporary() {
        let dir = tempfile::tempdir().unwrap();
        let path = dir.path().join("image.png");
        fs::write(&path, b"original image").unwrap();
        let result = replace_file(&path, None, false, |file| {
            file.write_all(b"partial output")?;
            Err(io::Error::other("simulated disk full"))
        });
        assert!(result.is_err());
        assert_eq!(fs::read(&path).unwrap(), b"original image");
        assert_eq!(fs::read_dir(dir.path()).unwrap().count(), 1);
    }

    #[test]
    fn failed_rename_cleans_up_temporary() {
        let dir = tempfile::tempdir().unwrap();
        let destination = dir.path().join("directory");
        fs::create_dir(&destination).unwrap();
        assert!(replace_file(&destination, None, false, |f| f.write_all(b"output")).is_err());
        assert!(destination.is_dir());
        assert_eq!(fs::read_dir(dir.path()).unwrap().count(), 1);
    }
}
