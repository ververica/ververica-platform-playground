#!/usr/bin/env bash

set -o errexit
set -o nounset
set -o pipefail

HELM=${HELM:-helm}
HELM_VERSION=

detect_helm_version() {
  local helm_version_string
  helm_version_string="$($HELM version --short --client)"

  if [[ "$helm_version_string" == *"v2"* ]]; then
    HELM_VERSION=2
  elif [[ "$helm_version_string" == *"v3"* ]]; then
    HELM_VERSION=3
  else
    echo >&2 "Unsupported Helm version: ${helm_version_string}"
    exit 1
  fi
}

helm_uninstall() {
  local release
  release="$1"

  if [ -z "$release" ]; then
    echo >&2 "error: release is required"
    return 1
  fi

  if [ "$HELM_VERSION" -eq 2 ]; then
    $HELM delete --purge "$release" || :
  else
    $HELM --namespace vvp delete "$release" || :
  fi
}

delete_namespaces() {
  kubectl get namespace vvp > /dev/null 2>&1 && kubectl delete namespace vvp || :
  kubectl get namespace vvp-jobs > /dev/null 2>&1 && kubectl delete namespace vvp-jobs || :
}

echo -n "> Detecting Helm version... "
detect_helm_version
echo "detected Helm ${HELM_VERSION}."

echo "> Uninstalling Helm applications..."
helm_uninstall minio
helm_uninstall vvp
helm_uninstall prometheus
helm_uninstall grafana

echo "> Deleting Kubernetes namespaces..."
delete_namespaces
