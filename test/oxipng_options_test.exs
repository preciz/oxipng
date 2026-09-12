defmodule OxipngOptionsTest do
  use ExUnit.Case, async: true

  alias Oxipng.Options

  test "unknown keys are rejected in every option container" do
    for opts <- [
          [max_decompresssed_size: 1],
          %{"level" => 6},
          %{level: 2, unknown: true},
          Map.put(%Options{}, :unknown, true)
        ] do
      assert {:error, reason} = Options.new(opts)
      assert reason =~ "Unknown options"
      assert_raise ArgumentError, fn -> Options.new!(opts) end
      assert {:error, ^reason} = Oxipng.optimize("invalid png", opts)
      assert_raise Oxipng.Error, fn -> Oxipng.optimize!("invalid png", opts) end
    end
  end

  test "malformed lists return errors instead of raising" do
    for opts <- [[:level], [{"level", 2}], [{:level, 2, 3}], [{:level, 2} | :bad]] do
      assert {:error, reason} = Options.new(opts)
      assert reason =~ "Options must be a keyword list or map"
      assert {:error, _} = Oxipng.optimize("invalid png", opts)
      assert_raise Oxipng.Error, fn -> Oxipng.optimize!("invalid png", opts) end
    end

    for opts <- [[filters: []], [filters: [:sub | :bad]], [strip: {:keep, ["tEXt" | :bad]}]] do
      assert {:error, _} = Options.new(opts)
    end
  end

  test "native integer overflow is rejected during option validation" do
    too_large = 18_446_744_073_709_551_616

    for opts <- [
          [timeout: too_large],
          [max_decompressed_size: too_large],
          [deflater: {:zopfli, too_large}],
          [deflater: {:zopfli, 1, too_large}],
          [filters: [{:brute, too_large, 1}]]
        ] do
      assert {:error, _} = Options.new(opts)
    end
  end
end
