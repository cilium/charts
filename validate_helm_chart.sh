#!/usr/bin/env bash
#
# Validate that the image tags in the Helm chart match the chart version.
#

set -e
shopt -s expand_aliases

DOCKER=${DOCKER:-docker}

helm() {
  "${DOCKER}" run --user "$(id -u):$(id -g)" --rm -v "$(pwd)":/apps alpine/helm:3.15.1 "$@"
}

yq () {
  "${DOCKER}" run -i --user "$(id -u):$(id -g)" --rm -v "${PWD}":/workdir mikefarah/yq:4.40.5 "$@"
}

usage() {
    >&2 echo "usage: $0 <chart-tgz-file|oci-chart-reference>"
    >&2 echo
    >&2 echo "example: $0 cilium-1.15.5.tgz"
    >&2 echo "example: $0 tetragon-1.1.0.tgz"
    >&2 echo "example: $0 oci://registry.example.com/cilium/cilium:1.15.5"
    >&2 echo "example: $0 oci://registry.example.com/cilium/tetragon:1.1.0"
}

CILIUM_IMAGE_PATHS=(
  '{$.clustermesh.apiserver.image.tag}'
  '{$.hubble.relay.image.tag}'
  '{$.image.tag}'
  '{$.operator.image.tag}'
  '{$.preflight.image.tag}'
)

TETRAGON_IMAGE_PATHS=(
  '{$.tetragon.image.tag}'
  '{$.tetragonOperator.image.tag}'
)

# $1 - Helm chart tgz file or OCI chart reference
main() {
  CHART="$1"

  if [ -z "$CHART" ]; then
      echo "ERROR: Chart argument is required"
      usage
      exit 1
  fi

  # Check if it's an OCI chart (starts with oci://) or a file
  if [[ ! "$CHART" =~ ^oci:// ]] && [ ! -f "$CHART" ]; then
      echo "ERROR: Chart file not found: $CHART"
      usage
      exit 1
  fi

  APP=$(helm show chart "$CHART" | yq e '.name' -)
  CHART_VERSION=$(helm show chart "$CHART" | yq e '.version' -)
  if [ "$APP" == "cilium" ]; then
    IMAGE_PATHS=("${CILIUM_IMAGE_PATHS[@]}")
  elif [ "$APP" == "tetragon" ]; then
    IMAGE_PATHS=("${TETRAGON_IMAGE_PATHS[@]}")
  else
    echo "Unsupported app $APP"
    exit 1
  fi

  for path in "${IMAGE_PATHS[@]}"; do
    tag=$(helm show values --jsonpath "$path" "$CHART")
    if [ "$tag" == "v$CHART_VERSION" ]; then
      echo "SUCCESS: $APP $path=$tag matches chart version $CHART_VERSION"
    else
      echo "ERROR: $APP $path=$tag does not match chart version $CHART_VERSION"
      exit 1
    fi
  done
}

main "$@"
