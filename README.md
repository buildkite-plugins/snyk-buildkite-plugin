
[![Build status](https://badge.buildkite.com/1d5cd674308d9572db45ebcb52aec5a32fd38b6763c3705b42.svg)](https://buildkite.com/buildkite/plugins-snyk)

# Snyk Buildkite Plugin

A Buildkite plugin that runs [Snyk](https://snyk.io) tests in your Buildkite pipelines

## Options

These are all the options available to configure this plugin's behaviour.

### Required

#### `scan` (string)

The type of scan that the plugin will perform. Currently supported options are `oss`, `code`, `container`. (default: `oss`)

### Optional

#### `token-env` (string)
The environment variable the plugin will reference to set `SNYK_TOKEN`. (default: `SNYK_TOKEN`)

#### `org` (string)
Your Snyk Organization slug, sets `SNYK_CFG_ORG`.

#### `image` (string)
The image and tag (example: `alpine:latest`) to pass to the container scan tool.

#### `annotate` (bool)
Annotate the build according to the scan results, default: FALSE

#### `block` (bool)
Optionally block the build on vulnerability detection


## Examples

Here are a few examples of using the plugin to scan within your Buildkite pipeline

```yaml
steps:
  - label: "🔎 Scanning with Snyk"
    plugins:
      - snyk#v0.1.0:
          scan: 'oss'
          annotate: true

```

## And with other options as well

```yaml
steps:
  - label: "🔎 Scanning code with Snyk"
    plugins:
      - snyk#v0.1.0:
          scan: 'code'
          annotate: true
```


Scanning a docker container image by image name and tag:

```yaml
steps:
  - label: "🔎 Scanning container image with Snyk"
    plugins:
      - snyk#v0.1.0:
          scan: 'container'
          annotate: true
          image: 'alpine:latest'

```

Block a build when a vulnerability is detected:

```yaml
steps:
  - label: "🔎 Blocking snyk scan"
    plugins:
      - snyk#v0.1.0:
          scan: 'oss'
          annotate: true
          block: true
```

## ⚒ Developing

### Tests

Run the tests using `docker compose run --rm tests`

### Running the pipeline
You can use the [bk cli](https://github.com/buildkite/cli) to run the [pipeline](.buildkite/pipeline.yml) locally:

```bash
bk local run
```

## 👩‍💻 Contributing

Your policy on how to contribute to the plugin!

## 📜 License

The package is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
