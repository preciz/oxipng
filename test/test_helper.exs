ExUnit.start(exclude: if(System.get_env("OXIPNG_TEST_DECODER"), do: [], else: [libpng: true]))
