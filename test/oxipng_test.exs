defmodule OxipngTest do
  use ExUnit.Case, async: true

  @sample_rgba <<
    255,
    0,
    0,
    255,
    0,
    255,
    0,
    255,
    0,
    0,
    255,
    255,
    255,
    255,
    255,
    255
  >>

  @sample_rgb <<
    255,
    0,
    0,
    0,
    255,
    0,
    0,
    0,
    255,
    255,
    255,
    255
  >>

  @sample_grayscale <<
    0,
    64,
    128,
    255
  >>

  @sample_grayscale_alpha <<
    0,
    255,
    64,
    255,
    128,
    255,
    255,
    255
  >>

  setup do
    {:ok, png} = Oxipng.create_optimized_from_raw(@sample_rgba, 2, 2)
    %{png: png}
  end

  describe "version/0" do
    test "returns the oxipng crate version string" do
      version = Oxipng.version()
      assert is_binary(version)
      assert version =~ ~r/^\d+\.\d+\.\d+$/
    end
  end

  describe "create_optimized_from_raw/6 and bang variant" do
    test "creates PNG from RGBA data" do
      assert {:ok, png} = Oxipng.create_optimized_from_raw(@sample_rgba, 2, 2, :rgba, 8)
      assert is_binary(png)
      assert <<0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, _rest::binary>> = png
    end

    test "creates PNG from RGB data" do
      assert {:ok, png} = Oxipng.create_optimized_from_raw(@sample_rgb, 2, 2, :rgb, 8)
      assert is_binary(png)
      assert <<0x89, 0x50, 0x4E, 0x47, _rest::binary>> = png
    end

    test "creates PNG from Grayscale data" do
      assert {:ok, png} = Oxipng.create_optimized_from_raw(@sample_grayscale, 2, 2, :grayscale, 8)
      assert is_binary(png)
      assert <<0x89, 0x50, 0x4E, 0x47, _rest::binary>> = png
    end

    test "creates PNG from GrayscaleAlpha data" do
      assert {:ok, png} =
               Oxipng.create_optimized_from_raw(
                 @sample_grayscale_alpha,
                 2,
                 2,
                 :grayscale_alpha,
                 8
               )

      assert is_binary(png)
      assert <<0x89, 0x50, 0x4E, 0x47, _rest::binary>> = png
    end

    test "bang variant returns binary directly" do
      png = Oxipng.create_optimized_from_raw!(@sample_rgba, 2, 2)
      assert is_binary(png)
      assert <<0x89, 0x50, 0x4E, 0x47, _rest::binary>> = png
    end

    test "fails with invalid pixel buffer length" do
      # 2x2 RGBA requires 16 bytes, only 10 provided
      short_data = <<0::size(80)>>

      assert {:error, reason} = Oxipng.create_optimized_from_raw(short_data, 2, 2, :rgba, 8)
      assert reason =~ "does not match the expected length"
    end

    test "bang variant raises on error" do
      assert_raise Oxipng.Error, fn ->
        Oxipng.create_optimized_from_raw!(<<1, 2, 3>>, 2, 2, :rgba, 8)
      end
    end
  end

  describe "optimize/2 and optimize!/2" do
    test "optimizes valid PNG binary with default options", %{png: png} do
      assert {:ok, optimized} = Oxipng.optimize(png)
      assert is_binary(optimized)
      assert <<0x89, 0x50, 0x4E, 0x47, _rest::binary>> = optimized
    end

    test "optimizes with preset levels (0 to 6)", %{png: png} do
      for level <- 0..6 do
        assert {:ok, optimized} = Oxipng.optimize(png, level: level)
        assert is_binary(optimized)
      end
    end

    test "optimizes with interlacing options", %{png: png} do
      assert {:ok, interlaced} = Oxipng.optimize(png, interlace: true)
      assert is_binary(interlaced)

      assert {:ok, non_interlaced} = Oxipng.optimize(png, interlace: false)
      assert is_binary(non_interlaced)

      assert {:ok, keep_interlaced} = Oxipng.optimize(png, interlace: :keep)
      assert is_binary(keep_interlaced)
    end

    test "optimizes with strip options", %{png: png} do
      assert {:ok, _} = Oxipng.optimize(png, strip: :none)
      assert {:ok, _} = Oxipng.optimize(png, strip: :safe)
      assert {:ok, _} = Oxipng.optimize(png, strip: :all)
      assert {:ok, _} = Oxipng.optimize(png, strip: true)
      assert {:ok, _} = Oxipng.optimize(png, strip: false)
      assert {:ok, _} = Oxipng.optimize(png, strip: {:keep, ["tEXt"]})
      assert {:ok, _} = Oxipng.optimize(png, strip: {:strip, ["tEXt"]})
      assert {:ok, _} = Oxipng.optimize(png, strip: {:keep, [:tEXt]})
    end

    test "optimizes with deflater options", %{png: png} do
      assert {:ok, _} = Oxipng.optimize(png, deflater: {:libdeflater, 6})
      assert {:ok, _} = Oxipng.optimize(png, deflater: :zopfli)
      assert {:ok, _} = Oxipng.optimize(png, deflater: {:zopfli, 5})
      assert {:ok, _} = Oxipng.optimize(png, deflater: {:zopfli, 5, 2})
    end

    test "optimizes with custom filters", %{png: png} do
      assert {:ok, _} = Oxipng.optimize(png, filters: [:sub, :up, :average, :paeth])
      assert {:ok, _} = Oxipng.optimize(png, filters: [:min_sum, :entropy, :bigrams, :big_ent])
      assert {:ok, _} = Oxipng.optimize(png, filters: [{:brute, 2, 1}])
    end

    test "optimizes with reduction flags", %{png: png} do
      assert {:ok, _} =
               Oxipng.optimize(png,
                 optimize_alpha: true,
                 bit_depth_reduction: true,
                 color_type_reduction: true,
                 palette_reduction: true,
                 grayscale_reduction: true,
                 idat_recoding: true,
                 scale_16: false,
                 fast_evaluation: true,
                 force: true
               )
    end

    test "optimize! returns binary directly", %{png: png} do
      optimized = Oxipng.optimize!(png, level: 1)
      assert is_binary(optimized)
      assert <<0x89, 0x50, 0x4E, 0x47, _rest::binary>> = optimized
    end

    test "returns error on non-PNG data" do
      assert {:error, reason} = Oxipng.optimize(<<"not a real png">>)
      assert reason =~ "Not a PNG file"
    end

    test "returns error on non-binary data" do
      assert {:error, reason} = Oxipng.optimize(12_345)
      assert reason =~ "Expected binary PNG data"
    end

    test "optimize! raises Oxipng.Error on failure" do
      assert_raise Oxipng.Error, ~r/Not a PNG file/, fn ->
        Oxipng.optimize!(<<"corrupted data">>)
      end
    end
  end

  describe "optimize_file/3 and optimize_file!/3" do
    @tag :tmp_dir
    test "optimizes file to a new destination", %{tmp_dir: tmp_dir, png: png} do
      in_path = Path.join(tmp_dir, "input.png")
      out_path = Path.join(tmp_dir, "output.png")
      File.write!(in_path, png)

      assert {:ok, %{in_bytes: in_bytes, out_bytes: out_bytes}} =
               Oxipng.optimize_file(in_path, out_path, level: 2)

      assert in_bytes > 0
      assert out_bytes > 0
      assert File.exists?(out_path)
      assert File.read!(out_path) =~ <<0x89, 0x50, 0x4E, 0x47>>
    end

    @tag :tmp_dir
    test "optimizes file in-place", %{tmp_dir: tmp_dir, png: png} do
      path = Path.join(tmp_dir, "inplace.png")
      File.write!(path, png)

      assert {:ok, %{in_bytes: in_bytes, out_bytes: out_bytes}} =
               Oxipng.optimize_file(path, level: 1)

      assert in_bytes > 0
      assert out_bytes > 0
      assert File.exists?(path)
    end

    @tag :tmp_dir
    test "optimize_file! returns stats directly", %{tmp_dir: tmp_dir, png: png} do
      path = Path.join(tmp_dir, "bang.png")
      File.write!(path, png)

      stats = Oxipng.optimize_file!(path, level: 1)
      assert %{in_bytes: in_bytes, out_bytes: out_bytes} = stats
      assert in_bytes > 0
      assert out_bytes > 0
    end

    test "returns error on missing input file" do
      assert {:error, reason} = Oxipng.optimize_file("non_existent_file_12345.png")
      assert is_binary(reason)
    end

    test "optimize_file! raises on missing input file" do
      assert_raise Oxipng.Error, fn ->
        Oxipng.optimize_file!("non_existent_file_12345.png")
      end
    end
  end

  describe "Options validation" do
    test "rejects invalid level" do
      assert {:error, reason} = Oxipng.Options.new(level: 7)
      assert reason =~ "Invalid :level"
    end

    test "rejects invalid interlace" do
      assert {:error, reason} = Oxipng.Options.new(interlace: :invalid)
      assert reason =~ "Invalid :interlace"
    end

    test "rejects invalid strip" do
      assert {:error, reason} = Oxipng.Options.new(strip: :foo)
      assert reason =~ "Invalid :strip"

      # Invalid chunk name (must be 4 bytes)
      assert {:error, reason} = Oxipng.Options.new(strip: {:keep, ["toolong"]})
      assert reason =~ "Invalid :strip"
    end

    test "rejects invalid deflater" do
      assert {:error, reason} = Oxipng.Options.new(deflater: {:libdeflater, 99})
      assert reason =~ "Invalid :deflater"

      assert {:error, reason} = Oxipng.Options.new(deflater: {:zopfli, 0})
      assert reason =~ "Invalid :deflater"
    end

    test "rejects invalid timeout" do
      assert {:error, reason} = Oxipng.Options.new(timeout: -10)
      assert reason =~ "Invalid :timeout"
    end

    test "rejects invalid boolean options" do
      assert {:error, reason} = Oxipng.Options.new(optimize_alpha: "yes")
      assert reason =~ "Invalid :optimize_alpha"

      assert {:error, reason} = Oxipng.Options.new(bit_depth_reduction: "yes")
      assert reason =~ "Invalid :bit_depth_reduction"

      assert {:error, reason} = Oxipng.Options.new(color_type_reduction: "yes")
      assert reason =~ "Invalid :color_type_reduction"

      assert {:error, reason} = Oxipng.Options.new(palette_reduction: "yes")
      assert reason =~ "Invalid :palette_reduction"

      assert {:error, reason} = Oxipng.Options.new(grayscale_reduction: "yes")
      assert reason =~ "Invalid :grayscale_reduction"

      assert {:error, reason} = Oxipng.Options.new(idat_recoding: "yes")
      assert reason =~ "Invalid :idat_recoding"

      assert {:error, reason} = Oxipng.Options.new(scale_16: "yes")
      assert reason =~ "Invalid :scale_16"

      assert {:error, reason} = Oxipng.Options.new(fast_evaluation: "yes")
      assert reason =~ "Invalid :fast_evaluation"

      assert {:error, reason} = Oxipng.Options.new(force: "yes")
      assert reason =~ "Invalid :force"

      assert {:error, reason} = Oxipng.Options.new(fix_errors: "yes")
      assert reason =~ "Invalid :fix_errors"

      assert {:error, reason} = Oxipng.Options.new(preserve_attrs: "yes")
      assert reason =~ "Invalid :preserve_attrs"
    end

    test "rejects invalid max_decompressed_size" do
      assert {:error, reason} = Oxipng.Options.new(max_decompressed_size: -10)
      assert reason =~ "Invalid :max_decompressed_size"
    end

    test "rejects invalid filters" do
      assert {:error, reason} = Oxipng.Options.new(filters: :not_a_list)
      assert reason =~ "Invalid :filters"

      assert {:error, reason} = Oxipng.Options.new(filters: [:not_a_filter])
      assert reason =~ "Invalid :filters"

      assert {:error, reason} = Oxipng.Options.new(filters: [{:brute, 0, 1}])
      assert reason =~ "Invalid :filters"

      assert {:error, reason} = Oxipng.Options.new(filters: [{:brute, 2, 13}])
      assert reason =~ "Invalid :filters"
    end

    test "rejects non-binary/atom chunk names" do
      assert {:error, reason} = Oxipng.Options.new(strip: {:strip, [1234]})
      assert reason =~ "Invalid :strip"
    end

    test "rejects non-map/list argument to Options.new" do
      assert {:error, reason} = Oxipng.Options.new(12_345)
      assert reason =~ "Options must be a keyword list or map"

      assert_raise ArgumentError, ~r/Options must be a keyword list or map/, fn ->
        Oxipng.Options.new!(12_345)
      end
    end

    test "rejects invalid deflater with zero iterations_without_improvement" do
      assert {:error, reason} = Oxipng.Options.new(deflater: {:zopfli, 5, 0})
      assert reason =~ "Invalid :deflater"
    end

    test "to_nif_map converts boolean strip and :keep interlace" do
      opts = Oxipng.Options.new!(strip: false, interlace: :keep)
      map = Oxipng.Options.to_nif_map(opts)
      assert map.strip == :none
      assert map.interlace == nil
    end

    test "accepts valid struct and keyword list" do
      assert {:ok, %Oxipng.Options{level: 4}} = Oxipng.Options.new(level: 4)
      assert %Oxipng.Options{level: 3} = Oxipng.Options.new!(level: 3)
    end
  end

  describe "create_optimized_from_raw error branches" do
    test "returns error on invalid width or height or data type" do
      assert {:error, reason} = Oxipng.create_optimized_from_raw(123, 10, 10)
      assert reason =~ "Invalid parameters"

      assert {:error, reason} = Oxipng.create_optimized_from_raw(<<0::size(32)>>, -1, 1)
      assert reason =~ "Invalid parameters"

      assert {:error, reason} = Oxipng.create_optimized_from_raw(<<0::size(32)>>, 1, 0)
      assert reason =~ "Invalid parameters"
    end

    test "returns error when invalid options passed" do
      assert {:error, reason} =
               Oxipng.create_optimized_from_raw(<<0::size(32)>>, 1, 1, :rgba, 8, level: 99)

      assert reason =~ "Invalid :level"
    end
  end
end
