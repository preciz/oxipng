defmodule OxipngVersionTest do
  use ExUnit.Case, async: true

  test "reported oxipng version matches the resolved dependency" do
    lock = File.read!(Path.expand("../native/oxipng_nif/Cargo.lock", __DIR__))
    [_, version] = Regex.run(~r/\[\[package\]\]\nname = "oxipng"\nversion = "([^"]+)"/, lock)
    assert Oxipng.version() == version
  end
end
