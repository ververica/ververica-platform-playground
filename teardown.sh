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

uninstall_vvp() {
  if [ "$HELM_VERSION" -eq 2 ]; then
    $HELM delete --purge vvp
  else
    $HELM --namespace vvp delete vvp
  fi
}

uninstall_minio() {
  if [ "$HELM_VERSION" -eq 2 ]; then
    $HELM delete --purge minio
  else
    $HELM --namespace vvp delete minio
  fi
}

delete_namespaces() {
  kubectl get namespace vvp > /dev/null 2>&1 && kubectl delete namespace vvp || :
  kubectl get namespace vvp-jobs > /dev/null 2>&1 && kubectl delete namespace vvp-jobs || :
}

echo -n "> Detecting Helm version... "
detect_helm_version
echo "detected Helm ${HELM_VERSION}."

echo "> Uninstalling Ververica Platform..."
uninstall_vvp || :

echo "> Uninstalling MinIO..."
uninstall_minio || :

echo "> Deleting Kubernetes namespaces..."
delete_namespaces
