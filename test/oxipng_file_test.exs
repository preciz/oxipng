defmodule OxipngFileTest do
  use ExUnit.Case, async: true

  @tag :tmp_dir
  test "invalid destinations never modify the input", %{tmp_dir: dir} do
    png = Oxipng.create_optimized_from_raw!(<<255, 0, 0, 255>>, 1, 1)
    input = Path.join(dir, "input.png")
    File.write!(input, png)

    for output <- ["", <<0>>, <<255>>, :invalid, 123, {}] do
      assert {:error, _} = Oxipng.optimize_file(input, output, force: true, interlace: true)
      assert_raise Oxipng.Error, fn -> Oxipng.optimize_file!(input, output) end
      assert File.read!(input) == png
    end

    for input <- ["", nil, 123, [:invalid], <<255>>] do
      assert {:error, _} = Oxipng.optimize_file(input)
    end
  end

  @tag :tmp_dir
  test "charlist paths are supported for both input and output", %{tmp_dir: dir} do
    input = Path.join(dir, "in.png")
    output = Path.join(dir, "out.png")
    File.write!(input, Oxipng.create_optimized_from_raw!(<<1, 2, 3, 255>>, 1, 1))
    assert {:ok, _} = Oxipng.optimize_file(to_charlist(input), to_charlist(output))
    assert File.exists?(output)
  end

  @tag :tmp_dir
  test "failed replacement retains the destination and cleans up temporary files", %{tmp_dir: dir} do
    input = Path.join(dir, "in.png")
    output = Path.join(dir, "directory")
    File.write!(input, Oxipng.create_optimized_from_raw!(<<1, 2, 3, 255>>, 1, 1))
    File.mkdir!(output)
    assert {:error, _} = Oxipng.optimize_file(input, output, force: true)
    assert File.dir?(output)
    assert Enum.sort(File.ls!(dir)) == ["directory", "in.png"]
  end

  @tag :tmp_dir
  test "preserve_attrs retains modification time", %{tmp_dir: dir} do
    input = Path.join(dir, "in.png")
    output = Path.join(dir, "out.png")
    File.write!(input, Oxipng.create_optimized_from_raw!(<<1, 2, 3, 255>>, 1, 1))
    time = {{2001, 2, 3}, {4, 5, 6}}
    File.touch!(input, time)
    assert {:ok, _} = Oxipng.optimize_file(input, output, preserve_attrs: true, force: true)
    assert File.stat!(output).mtime == time
    assert {:ok, _} = Oxipng.optimize_file(input, preserve_attrs: true, force: true)
    assert File.stat!(input).mtime == time
  end

  if match?({:unix, _}, :os.type()) do
    @tag :tmp_dir
    test "replacements follow symlinks and retain destination permissions", %{tmp_dir: dir} do
      target = Path.join(dir, "target.png")
      link = Path.join(dir, "link.png")
      png = Oxipng.create_optimized_from_raw!(<<1, 2, 3, 255>>, 1, 1)
      File.write!(target, png)
      File.chmod!(target, 0o640)
      File.ln_s!(target, link)
      assert {:ok, _} = Oxipng.optimize_file(link, force: true, interlace: true)
      assert File.lstat!(link).type == :symlink
      assert File.read!(target) != png
      assert Bitwise.band(File.stat!(target).mode, 0o777) == 0o640

      File.write!(target, png)
      assert {:ok, _} = Oxipng.optimize_file(target, link, force: true, interlace: true)
      assert File.lstat!(link).type == :symlink
      assert File.read!(target) != png
    end
  end
end
