#!/usr/bin/env bats

setup() {
  load "${BATS_PLUGIN_PATH}/load.bash"

  # Uncomment to enable stub debugging
  # export CURL_STUB_DEBUG=/dev/tty
  #  export SNYK_STUB_DEBUG=/dev/tty
  #  export SNYK_TO_HTML_STUB_DEBUG=/dev/tty
  #  export BUILDKITE_AGENT_STUB_DEBUG=/dev/tty

  # you can set variables common to all tests here
  export BUILDKITE_PLUGIN_YOUR_PLUGIN_NAME_MANDATORY='Value'
  export BUILDKITE_PLUGIN_SNYK_SCAN='code'
  export BUILDKITE_PLUGIN_SNYK_TOKEN_ENV='FOO'
  export BUILDKITE_PLUGIN_SNYK_IMAGE='llama'
  export BUILDKITE_PIPELINE_SLUG='bk'
  export BUILDKITE_BUILD_NUMBER='1'
  export FOO='BAR'
  export BUILDKITE_PLUGIN_SNYK_ANNOTATE=false
}

teardown() {
  unstub snyk || true
  unstub snyk-to-html || true
  unstub buildkite-agent || true
}

@test "missing snyk token causes plugin to fail" {
  unset BUILDKITE_PLUGIN_SNYK_TOKEN_ENV
  unset SNYK_TOKEN

  run "$PWD"/hooks/post-command

  assert_failure
  assert_output --partial 'No token set'
  refute_output --partial 'Running plugin'
}

@test "oss option runs Snyk OSS scan" {
  BUILDKITE_PLUGIN_SNYK_SCAN='oss'

  stub snyk \
   "test --json-file-output=${BUILDKITE_PIPELINE_SLUG}-${BUILDKITE_BUILD_NUMBER}-snyk-oss.json : echo 'Scanning OSS'"

  stub snyk-to-html \
  "-i ${BUILDKITE_PIPELINE_SLUG}-${BUILDKITE_BUILD_NUMBER}-snyk-oss.json -o ${BUILDKITE_PIPELINE_SLUG}-${BUILDKITE_BUILD_NUMBER}-oss.html : echo 'created artifact'"

  stub buildkite-agent \
  "artifact upload ${BUILDKITE_PIPELINE_SLUG}-${BUILDKITE_BUILD_NUMBER}-oss.html : exit 0" \
  "annotate \* \* \* \* \* : exit 0"

  run "$PWD"/hooks/post-command

  assert_success
  assert_output --partial 'Scanning OSS'
}

@test "code option runs Snyk code scan" {
  BUILDKITE_PLUGIN_SNYK_SCAN='code'

  stub snyk \
   "code test --json-file-output=${BUILDKITE_PIPELINE_SLUG}-${BUILDKITE_BUILD_NUMBER}-snyk-code.json : echo 'Scanning Code'"

  run "$PWD"/hooks/post-command

  assert_success
  assert_output --partial 'Scanning Code'
}

@test "container option runs Snyk container scan" {
  BUILDKITE_PLUGIN_SNYK_SCAN='container'

  stub snyk \
   "container test llama --json-file-output=${BUILDKITE_PIPELINE_SLUG}-${BUILDKITE_BUILD_NUMBER}-snyk-container.json : echo 'Scanning Container llama'"

  stub snyk-to-html \
  "-i ${BUILDKITE_PIPELINE_SLUG}-${BUILDKITE_BUILD_NUMBER}-snyk-container.json -o ${BUILDKITE_PIPELINE_SLUG}-${BUILDKITE_BUILD_NUMBER}-container.html : echo 'created artifact'"

  stub buildkite-agent \
  "artifact upload ${BUILDKITE_PIPELINE_SLUG}-${BUILDKITE_BUILD_NUMBER}-container.html : exit 0" \
  "annotate \* \* \* \* \* : exit 0"

  run "$PWD"/hooks/post-command

  assert_success
  assert_output --partial 'Scanning Container llama'
}

@test "snyk plugin does not annotate when annotate is false" {
  export BUILDKITE_PLUGIN_SNYK_ANNOTATE=false
  BUILDKITE_PLUGIN_SNYK_SCAN='oss'

  stub snyk \
   "test --json-file-output=${BUILDKITE_PIPELINE_SLUG}-${BUILDKITE_BUILD_NUMBER}-snyk-oss.json : echo 'Scanning OSS'"

  stub snyk-to-html \
  "-i ${BUILDKITE_PIPELINE_SLUG}-${BUILDKITE_BUILD_NUMBER}-snyk-oss.json -o ${BUILDKITE_PIPELINE_SLUG}-${BUILDKITE_BUILD_NUMBER}-oss.html : echo 'created artifact'"

  stub buildkite-agent \
  "artifact upload ${BUILDKITE_PIPELINE_SLUG}-${BUILDKITE_BUILD_NUMBER}-oss.html : exit 0" \
  "annotate \* \* \* \* \* : exit 0"

  run "$PWD"/hooks/post-command

  assert_success
  assert_output --partial 'Scanning OSS'
  refute_output --partial 'annotate'
}

@test "snyk plugin annotates when annotate is true" {
  export BUILDKITE_PLUGIN_SNYK_ANNOTATE=true
  BUILDKITE_PLUGIN_SNYK_SCAN='oss'

  stub snyk \
   "test --json-file-output=${BUILDKITE_PIPELINE_SLUG}-${BUILDKITE_BUILD_NUMBER}-snyk-oss.json : echo 'Scanning OSS'"

  stub snyk-to-html \
  "-i ${BUILDKITE_PIPELINE_SLUG}-${BUILDKITE_BUILD_NUMBER}-snyk-oss.json -o ${BUILDKITE_PIPELINE_SLUG}-${BUILDKITE_BUILD_NUMBER}-oss.html : echo 'created artifact'"

  stub buildkite-agent \
  "artifact upload ${BUILDKITE_PIPELINE_SLUG}-${BUILDKITE_BUILD_NUMBER}-oss.html : exit 0" \
  "annotate \* \* \* \* \* : echo 'Annotation created'"

  run "$PWD"/hooks/post-command

  assert_success
  assert_output --partial 'Scanning OSS'
  assert_output --partial 'Annotation created'
}
