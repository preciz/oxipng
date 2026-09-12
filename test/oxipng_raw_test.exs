defmodule OxipngRawTest do
  use ExUnit.Case, async: true

  test "raw dimension and depth errors have consistent tuple and bang behavior" do
    for {width, height, depth} <- [
          {2_147_483_648, 1, 8},
          {1, 4_294_967_296, 8},
          {1, 1, -1},
          {1, 1, 256},
          {1, 1, 8.0},
          {1, 1, :eight}
        ] do
      assert {:error, _} =
               Oxipng.create_optimized_from_raw(<<0>>, width, height, :grayscale, depth)

      assert_raise Oxipng.Error, fn ->
        Oxipng.create_optimized_from_raw!(<<0>>, width, height, :grayscale, depth)
      end
    end
  end

  test "indexed palette validation is independent of reductions" do
    disabled = [palette_reduction: false, bit_depth_reduction: false, color_type_reduction: false]

    for opts <- [[], disabled],
        {palette, depth} <- [
          {<<>>, 8},
          {<<1, 2, 3>>, 8},
          {:binary.copy(<<255, 0, 0, 255>>, 257), 8},
          {:binary.copy(<<255, 0, 0, 255>>, 3), 1}
        ] do
      assert {:error, _} =
               Oxipng.create_optimized_from_raw(<<0>>, 1, 1, {:indexed, palette}, depth, opts)
    end
  end

  test "packed indices are checked per row while padding bits are ignored" do
    palette = <<255, 0, 0, 255>>

    for {depth, invalid, padding} <- [{1, 128, 127}, {2, 64, 63}, {4, 16, 15}, {8, 1, 0}] do
      assert {:error, reason} =
               Oxipng.create_optimized_from_raw(<<0, invalid>>, 1, 2, {:indexed, palette}, depth)

      assert reason =~ "outside"

      assert {:ok, _} =
               Oxipng.create_optimized_from_raw(
                 <<padding, padding>>,
                 1,
                 2,
                 {:indexed, palette},
                 depth
               )
    end
  end
end
