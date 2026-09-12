import Config

# Used to test the exact release archives through RustlerPrecompiled's downloader.
if base_url = System.get_env("OXIPNG_BASE_URL") do
  config :oxipng, base_url: base_url
end
