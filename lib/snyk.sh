#!/bin/bash

set -euo pipefail

function configure_plugin() {
    # Set token for the SNYK cli (either Service Account or User token)
    if [ -z "${BUILDKITE_PLUGIN_SNYK_TOKEN_ENV:-}" ]; then
       export SNYK_TOKEN="${SNYK_TOKEN?No token set}"
    else
       export SNYK_TOKEN="${!BUILDKITE_PLUGIN_SNYK_TOKEN_ENV}"
    fi

    if [[ -z "${SNYK_TOKEN:-}" ]]; then
        echo " +++ 🚨 No Snyk token set"
        exit 1
    fi

    # Check for an org configuration
    if [[ -n "${BUILDKITE_PLUGIN_SNYK_ORG:-}" ]]; then
        export SNYK_CFG_ORG="${BUILDKITE_PLUGIN_SNYK_ORG}"
    fi

    # Make sure we have a scan target (code, oss, container, etc)
    if [[ -n "${BUILDKITE_PLUGIN_SNYK_SCAN:-}" ]]; then
        scan_tool="${BUILDKITE_PLUGIN_SNYK_SCAN?No option to scan}"
    fi

    # Check for an image tag being passed from the plugin config
    if [[ -n "${BUILDKITE_PLUGIN_SNYK_IMAGE:-}" ]]; then
        export CONTAINER_IMAGE="${BUILDKITE_PLUGIN_SNYK_IMAGE?no image name configured}"
    fi

    # Check for annotate attribute in plugin config
    if [[ "${BUILDKITE_PLUGIN_SNYK_ANNOTATE:-}" == "false" ]]; then
        annotate=false
    else
        annotate=true
    fi
}

function snyk_scan() {
    case "${scan_tool}" in
        oss)
        snyk_oss_test
        ;;

        code)
        snyk_code_test
        ;;

        container)
        snyk_container_test
        ;;
    esac
}

function snyk_oss_test () {
    json_output_file="${BUILDKITE_PIPELINE_SLUG}-${BUILDKITE_BUILD_NUMBER}-snyk-oss.json"

    echo "--- Running Snyk OSS scan"

    exit_code=0
    snyk test --json-file-output="${json_output_file}" || exit_code=$?

    upload_results "${json_output_file}" "oss"

    if [[ "${annotate}" == "true" ]]; then
       annotate_build "${exit_code}" "oss"
    fi

    if [[ "${exit_code}" != 0 && "${BUILDKITE_PLUGIN_SNYK_BLOCK:-}" == true ]]; then
        block_build
    fi
}

function snyk_code_test () {
    json_output_file="${BUILDKITE_PIPELINE_SLUG}-${BUILDKITE_BUILD_NUMBER}-snyk-code.json"

    echo "--- Running Snyk Code scan"

    exit_code=0
    snyk code test --json-file-output="${json_output_file}" || exit_code=$?

    if [ -f "${json_output_file}" ]; then
        upload_results "${json_output_file}" "code"

        if [[ "${annotate}" == "true" ]]; then
            annotate_build "${exit_code:0}" "code"
        fi
    fi

    if [[ "${exit_code}" != 0 && "${BUILDKITE_PLUGIN_SNYK_BLOCK:-}" == true ]]; then
        block_build
    fi
}

function snyk_container_test() {
    json_output_file="${BUILDKITE_PIPELINE_SLUG}-${BUILDKITE_BUILD_NUMBER}-snyk-container.json"
    echo "--- Running Snyk Container scan"
    if [[ -n "${CONTAINER_IMAGE}" ]]; then
        exit_code=0
        snyk container test "${CONTAINER_IMAGE:-}" --json-file-output="${json_output_file}" || exit_code=$?

        upload_results "${json_output_file}" "container"

        if [[ "${annotate}" == "true" ]]; then
            annotate_build "${exit_code}" "container"
        fi
    else
        echo "no container image provided"
        exit 1
    fi

    if [[ "${exit_code}" != 0 && "${BUILDKITE_PLUGIN_SNYK_BLOCK:-}" == true ]]; then
        block_build
    fi
}

function block_build() {
    echo "Snyk detected vulnerabilities in the test, blocking build"

    cat << EOF | buildkite-agent pipeline upload
        steps:
            - block: ":snyk: detected vulnerabilities, continue?"
EOF
}

function upload_results() {
    json_result_file=$1
    ctx=$2

    html_artifact="${BUILDKITE_PIPELINE_SLUG}-${BUILDKITE_BUILD_NUMBER}-${ctx}.html"

    snyk-to-html -i "${json_result_file}" -o "${html_artifact}"

    echo "--- Uploading artifacts"
    buildkite-agent artifact upload "${html_artifact}"
}

function annotate_build() {
    exit_code=$1
    ctx=$2

    html_artifact="${BUILDKITE_PIPELINE_SLUG}-${BUILDKITE_BUILD_NUMBER}-${ctx}.html"

    if [[ "${exit_code}" != 0 ]]; then
        style="error"
        message="<p>Snyk test completed and vulnerabilities were detected. Complete results have been uploaded as a build artifact.</p>"
    else
        style="success"
        message="<p>Snyk test completed and uploaded the results as a build artifact.</p>"
    fi

    annotation=$(cat << EOF
   <h3>Snyk ${ctx} test</h3>
   ${message}
    <a href=artifact://${html_artifact}>View Complete Scan Result</a>
EOF
)

    buildkite-agent annotate "${annotation}" --style "${style}" --context "${ctx}"
}
