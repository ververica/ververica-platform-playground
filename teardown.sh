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
    echo 2
  elif [[ "$helm_version_string" == *"v3"* ]]; then
    echo 3
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
    $HELM delete --purge "$release" 2>/dev/null || :
  else
    $HELM --namespace vvp delete "$release" 2>/dev/null || :
  fi
}

delete_namespaces() {
  kubectl get namespace vvp > /dev/null 2>&1 && kubectl delete namespace vvp || :
  kubectl get namespace vvp-jobs > /dev/null 2>&1 && kubectl delete namespace vvp-jobs || :
}

main() {
  local kube_context
  kube_context="$(kubectl config current-context)"

  echo -n "This script will delete all playground components and the 'vvp' and "
  echo "'vvp-jobs' namespaces from Kubernetes."
  echo
  echo "The currently configured Kubernetes context is: ${kube_context}"
  echo
  read -r -p "Are you sure you want to continue? (Y/n) " yn

  case $yn in
    "Y")
      ;;
    *)
      echo "Aborted."
      exit 1
      ;;
  esac

  echo -n "> Detecting Helm version... "
  HELM_VERSION="$(detect_helm_version)"
  echo "detected Helm ${HELM_VERSION}."
 
  echo "> Uninstalling Helm applications..."
  helm_uninstall minio
  helm_uninstall vvp
  helm_uninstall prometheus
  helm_uninstall grafana
  helm_uninstall elasticsearch

  echo "> Deleting Kubernetes namespaces..."
  delete_namespaces
}

main
