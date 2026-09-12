[directory | flags] = System.argv()
[_, version] = Regex.run(~r/@version "([^"]+)"/, File.read!("mix.exs"))
archives = Path.wildcard(Path.join(directory, "*.tar.gz"))

if archives == [] or ("--all" in flags and length(archives) != 9) do
  raise "Expected #{if "--all" in flags, do: "all nine", else: "at least one"} NIF archives"
end

checksums =
  Map.new(archives, fn path ->
    name = Path.basename(path)

    unless String.contains?(name, "oxipng_nif-v#{version}-nif-2.15-") do
      raise "Archive does not match project version #{version}: #{name}"
    end

    checksum = :crypto.hash(:sha256, File.read!(path)) |> Base.encode16(case: :lower)
    {name, "sha256:" <> checksum}
  end)

File.write!(
  "checksum-Elixir.Oxipng.Native.exs",
  inspect(checksums, pretty: true, limit: :infinity) <> "\n"
)
