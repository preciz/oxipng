defmodule OxipngIntegrityTest do
  use ExUnit.Case, async: true

  @moduletag :libpng
  @moduletag :tmp_dir

  test "grayscale samples survive creation and optimization at every depth", %{tmp_dir: dir} do
    for depth <- [1, 2, 4, 8, 16], interlace <- [false, true] do
      max = Bitwise.bsl(1, depth) - 1
      samples = for n <- 0..5, do: rem(n * 7, max + 1)
      data = pack_rows(samples, 3, depth)

      expected =
        for sample <- samples, into: <<>> do
          value = div(sample * 65_535, max)
          <<value::16, value::16, value::16, 65_535::16>>
        end

      assert_pixels(dir, data, :grayscale, depth, expected, interlace)
    end
  end

  test "RGB and alpha samples survive creation and optimization", %{tmp_dir: dir} do
    for {color, channels} <- [rgba: 4, rgb: 3, grayscale_alpha: 2],
        depth <- [8, 16],
        interlace <- [false, true] do
      max = Bitwise.bsl(1, depth) - 1

      pixels =
        for n <- 0..5 do
          for channel <- 0..(channels - 1), do: rem(n * 1031 + channel * 113, max + 1)
        end

      data = for pixel <- pixels, sample <- pixel, into: <<>>, do: <<sample::size(depth)>>

      expected =
        for pixel <- pixels, into: <<>> do
          rgba =
            case {color, pixel} do
              {:rgba, values} -> values
              {:rgb, values} -> values ++ [max]
              {:grayscale_alpha, [gray, alpha]} -> [gray, gray, gray, alpha]
            end

          for value <- rgba, into: <<>>, do: <<div(value * 65_535, max)::16>>
        end

      assert_pixels(dir, data, color, depth, expected, interlace)
    end
  end

  test "indexed samples survive creation and optimization at every depth", %{tmp_dir: dir} do
    palette = <<255, 0, 0, 255, 0, 255, 0, 127>>
    samples = [0, 1, 0, 1, 0, 1]

    expected =
      for sample <- samples, into: <<>> do
        if sample == 0,
          do: <<65_535::16, 0::16, 0::16, 65_535::16>>,
          else: <<0::16, 65_535::16, 0::16, 32_639::16>>
      end

    for depth <- [1, 2, 4, 8], interlace <- [false, true] do
      assert_pixels(
        dir,
        pack_rows(samples, 3, depth),
        {:indexed, palette},
        depth,
        expected,
        interlace
      )
    end
  end

  test "lossless defaults preserve hidden RGB values in transparent pixels", %{tmp_dir: dir} do
    data = <<255, 1, 2, 0, 3, 254, 4, 0, 5, 6, 253, 0, 1, 2, 3, 255, 4, 5, 6, 127, 7, 8, 9, 255>>
    expected = for <<value <- data>>, into: <<>>, do: <<value * 257::16>>
    assert_pixels(dir, data, :rgba, 8, expected, false)
  end

  defp pack_rows(samples, width, depth) do
    samples
    |> Enum.chunk_every(width)
    |> Enum.map(fn row ->
      bits = for sample <- row, into: <<>>, do: <<sample::size(depth)>>
      padding = rem(8 - rem(bit_size(bits), 8), 8)
      <<bits::bitstring, 0::size(padding)>>
    end)
    |> IO.iodata_to_binary()
  end

  defp assert_pixels(dir, data, color, depth, expected, interlace) do
    opts = [interlace: interlace, force: true]
    assert {:ok, png} = Oxipng.create_optimized_from_raw(data, 3, 2, color, depth, opts)
    assert {:ok, optimized} = Oxipng.optimize(png, opts)

    for output <- [png, optimized] do
      path = Path.join(dir, "image.png")
      File.write!(path, output)

      assert {_, 0} =
               System.cmd(System.fetch_env!("OXIPNG_TEST_DECODER"), [path, path <> ".rgba16"],
                 stderr_to_stdout: true
               )

      assert File.read!(path <> ".rgba16") == expected,
             "Pixel mismatch for #{inspect(color)} at depth #{depth}, interlace #{interlace}"
    end
  end
end
