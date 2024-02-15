#!/bin/bash

set -euo pipefail


function configure_plugin() {

    # PLUGIN_DIR="$(cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd)/.."
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
    if [[ -n "${BUILDKITE_PLUGIN_SNYK_ANNOTATE:-}"  ]]; then
        annotate="${BUILDKITE_PLUGIN_SNYK_ANNOTATE}"
    else
        annotate=false
    fi
}

# Snyk Scans based on the provided scan tool
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

    snyk test --json-file-output="${json_output_file}"
    # capture the exit code to use for formatting the annotation later (https://docs.snyk.io/snyk-cli/commands/code-test#exit-codes)
    exit_code=$?

    upload_results "${json_output_file}" "snyk-oss"

    # Only create the annotation if annotate: true is added to the plugin config, default is "false"
    if [[ "${annotate}" ]]; then
       annotate_build "${exit_code}" "snyk-oss"
    fi
}

# Runs Snyk Code tests
function snyk_code_test () {
    json_output_file="${BUILDKITE_PIPELINE_SLUG}-${BUILDKITE_BUILD_NUMBER}-snyk-code.json"

    echo "--- Running Snyk Code scan"

    snyk code test --json-file-output="${json_output_file}"
    # capture the exit code to use for formatting the annotation later (https://docs.snyk.io/snyk-cli/commands/code-test#exit-codes)
    exit_code=$?

    upload_results "${json_output_file}" "snyk-code"

    # Only create the annotation if annotate: true is added to the plugin config, default is "false"
    if [[ "${annotate}" ]]; then
       annotate_build "${exit_code}" "snyk-code"
    fi
}

# Run container test against a container image built as part of the job
# TODO: implement container tests entirely
function snyk_container_test() {
    json_output_file="${BUILDKITE_PIPELINE_SLUG}-${BUILDKITE_BUILD_NUMBER}-snyk-container.json"
    echo "--- Running Snyk Container scan"
    if [[ -n "${CONTAINER_IMAGE}" ]]; then
        snyk container test "${CONTAINER_IMAGE:-}" --json-file-output=snyk-results.json
        exit_code=$?
         upload_results "${json_output_file}" "snyk-container"

        # Only create the annotation if annotate: true is added to the plugin config, default is "false"
        if [[ "${annotate}" ]]; then
        annotate_build "${exit_code}" "snyk-container"
        fi
    else
        echo "no container image provided"
        exit 1
    fi
}


# Format the JSON results from the test into nice HTML and add a build artifact
function upload_results() {
    json_result_file=$1
    ctx=$2

    html_artifact="${BUILDKITE_PIPELINE_SLUG}-${BUILDKITE_BUILD_NUMBER}-${ctx}.html"

    # convert the 
    snyk-to-html -i "${json_result_file}" -o "${html_artifact}"

    echo "--- Uploading artifacts"
    buildkite-agent artifact upload "${html_artifact}"

}


# format the output into an annotation with a link to the full report as an artifact
function annotate_build() {
    exit_code=$1
    ctx=$2
    html_artifact="${BUILDKITE_PIPELINE_SLUG}-${BUILDKITE_BUILD_NUMBER}-${ctx}.html"

    if [[ "${exit_code}" != 0 ]]; then
        style="error"
    else
        style="success"
    fi
    
    annotation=$(
    cat << EOF
    Snyk Scan completed, see the <a href="artifact://${html_artifact}">uploaded results</a>
EOF
)
   
    buildkite-agent annotate "${annotation}" --style "${style}" --context "${ctx}"
}

