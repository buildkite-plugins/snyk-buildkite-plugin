#!/usr/bin/env bats

setup() {
  load "${BATS_PLUGIN_PATH}/load.bash"

  # Uncomment to enable stub debugging
  # export CURL_STUB_DEBUG=/dev/tty
  # export SNYK_STUB_DEBUG=/dev/tty

  # you can set variables common to all tests here
  export BUILDKITE_PLUGIN_YOUR_PLUGIN_NAME_MANDATORY='Value'
  export BUILDKITE_PLUGIN_SNYK_SCAN='code'
  export BUILDKITE_PLUGIN_SNYK_TOKEN_ENV='FOO'
  export BUILDKITE_PLUGIN_SNYK_IMAGE='llama'
  export BUILDKITE_PIPELINE_SLUG='bk'
  export BUILDKITE_BUILD_NUMBER='kb'
  export FOO='BAR'
}


@test "missing snyk token causes plugin to fail" {
  unset BUILDKITE_PLUGIN_SNYK_TOKEN_ENV
  unset SNYK_TOKEN

  run "$PWD"/hooks/command

  assert_failure
  assert_output --partial 'No token set'
  refute_output --partial 'Running plugin'
}

@test "setting token env attribute sets snyk token" {

}


@test "oss option runs Snyk OSS scan" {
  BUILDKITE_PLUGIN_SNYK_SCAN='oss'

  stub snyk \
   "test --json-file-output=snyk-results.json : echo 'Scanning OSS'"

  run "$PWD"/hooks/command

  assert_success
  assert_output --partial 'Running Snyk OSS scan'
  assert_output --partial 'Scanning OSS'

  unstub snyk
}

@test "code option runs Snyk code scan" {
  BUILDKITE_PLUGIN_SNYK_SCAN='code'

  stub snyk \
   "code test --json-file-output=snyk-results.json : echo 'Scanning Code'"

  run "$PWD"/hooks/command

  assert_success
  assert_output --partial 'Running Snyk Code scan'
  assert_output --partial 'Scanning Code'

  unstub snyk
}

@test "container option runs Snyk container scan" {
  BUILDKITE_PLUGIN_SNYK_SCAN='container'

  stub snyk \
   "container test llama --json-file-output=snyk-results.json : echo 'Scanning Container llama'"

  run "$PWD"/hooks/command

  assert_success
  assert_output --partial 'Running Snyk Container scan'
  assert_output --partial 'Scanning Container llama'

  unstub snyk
}