defmodule OxipngPropertyTest do
  use ExUnit.Case, async: true
  use ExUnitProperties

  defp valid_options_generator do
    gen all(
          level <- StreamData.integer(0..6),
          interlace <- StreamData.member_of([nil, :keep, true, false]),
          strip <- StreamData.member_of([:none, :safe, :all, true, false]),
          optimize_alpha <- StreamData.boolean(),
          bit_depth_reduction <- StreamData.boolean(),
          color_type_reduction <- StreamData.boolean(),
          palette_reduction <- StreamData.boolean(),
          grayscale_reduction <- StreamData.boolean(),
          idat_recoding <- StreamData.boolean(),
          scale_16 <- StreamData.boolean(),
          force <- StreamData.boolean(),
          fix_errors <- StreamData.boolean(),
          preserve_attrs <- StreamData.boolean(),
          timeout <- StreamData.one_of([StreamData.constant(nil), StreamData.positive_integer()]),
          deflater <-
            StreamData.member_of([
              nil,
              :zopfli,
              {:libdeflater, 6},
              {:zopfli, 5}
            ])
        ) do
      [
        level: level,
        interlace: interlace,
        strip: strip,
        optimize_alpha: optimize_alpha,
        bit_depth_reduction: bit_depth_reduction,
        color_type_reduction: color_type_reduction,
        palette_reduction: palette_reduction,
        grayscale_reduction: grayscale_reduction,
        idat_recoding: idat_recoding,
        scale_16: scale_16,
        force: force,
        fix_errors: fix_errors,
        preserve_attrs: preserve_attrs,
        timeout: timeout,
        deflater: deflater
      ]
    end
  end

  describe "Fuzzing & Crash Safety" do
    property "never crashes or segfaults on arbitrary binary input" do
      check all(
              binary <- StreamData.binary(),
              level <- StreamData.integer(0..2),
              max_runs: 50
            ) do
        case Oxipng.optimize(binary, level: level) do
          {:ok, result} -> assert is_binary(result)
          {:error, reason} -> assert is_binary(reason)
        end
      end
    end
  end

  describe "Round-trip & Integrity" do
    property "raw RGBA pixel buffers generate valid optimizable PNGs" do
      check all(
              width <- StreamData.integer(1..16),
              height <- StreamData.integer(1..16),
              pixels <- StreamData.binary(length: width * height * 4),
              level <- StreamData.integer(0..2),
              max_runs: 30
            ) do
        assert {:ok, png} =
                 Oxipng.create_optimized_from_raw(pixels, width, height, :rgba, 8, level: level)

        assert <<0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, _rest::binary>> = png
        assert {:ok, reoptimized} = Oxipng.optimize(png, level: level)
        assert is_binary(reoptimized)
        assert byte_size(reoptimized) <= byte_size(png)
      end
    end

    property "raw RGB pixel buffers generate valid PNGs" do
      check all(
              width <- StreamData.integer(1..16),
              height <- StreamData.integer(1..16),
              pixels <- StreamData.binary(length: width * height * 3),
              max_runs: 25
            ) do
        assert {:ok, png} =
                 Oxipng.create_optimized_from_raw(pixels, width, height, :rgb, 8, level: 1)

        assert <<0x89, 0x50, 0x4E, 0x47, _rest::binary>> = png
      end
    end

    property "re-optimizing an already optimized PNG does not expand" do
      check all(
              width <- StreamData.integer(2..12),
              height <- StreamData.integer(2..12),
              pixels <- StreamData.binary(length: width * height * 4),
              max_runs: 25
            ) do
        {:ok, png1} = Oxipng.create_optimized_from_raw(pixels, width, height, :rgba, 8, level: 1)
        {:ok, png2} = Oxipng.optimize(png1, level: 1)
        {:ok, png3} = Oxipng.optimize(png2, level: 1)

        assert byte_size(png3) <= byte_size(png2)
      end
    end
  end

  describe "Options Validation Properties" do
    property "all generated valid options succeed in Options.new" do
      check all(
              opts <- valid_options_generator(),
              max_runs: 40
            ) do
        assert {:ok, %Oxipng.Options{} = options} = Oxipng.Options.new(opts)
        nif_map = Oxipng.Options.to_nif_map(options)
        assert is_map(nif_map)
        assert Map.has_key?(nif_map, :level)
        assert Map.has_key?(nif_map, :strip)
      end
    end

    property "invalid levels always return an error" do
      invalid_levels =
        StreamData.one_of([
          StreamData.integer(-1000..-1),
          StreamData.integer(7..1000)
        ])

      check all(
              level <- invalid_levels,
              max_runs: 30
            ) do
        assert {:error, reason} = Oxipng.Options.new(level: level)
        assert reason =~ "Invalid :level"
      end
    end

    property "invalid timeouts always return an error" do
      invalid_timeouts = StreamData.integer(-1000..0)

      check all(
              timeout <- invalid_timeouts,
              max_runs: 30
            ) do
        assert {:error, reason} = Oxipng.Options.new(timeout: timeout)
        assert reason =~ "Invalid :timeout"
      end
    end
  end
end
