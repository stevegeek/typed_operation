D = Steep::Diagnostic

target :lib do
  signature "sig"
  check "lib"
  ignore "lib/generators"

  collection_config "rbs_collection.yaml"

  configure_code_diagnostics(D::Ruby.default)
end

target :rbs_tests do
  signature File.expand_path("sig", __dir__)
  signature File.expand_path("test/rbs", __dir__)
  # signature "sig"
  # signature "test/rbs"

  check "test/rbs"

  collection_config "rbs_collection.yaml"

  configure_code_diagnostics(D::Ruby.default)
end
