#!/usr/bin/env bash

set -o errexit
set -o nounset
set -o pipefail

HELM=${HELM:-helm}

helm_uninstall() {
  local release
  release="$1"

  if [ -z "$release" ]; then
    echo >&2 "error: release is required"
    return 1
  fi

  $HELM --namespace vvp delete "$release" 2>/dev/null || :
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
  read -r -p "Are you sure you want to continue? (y/N) " yn

  case $yn in
    "y")
      ;;
    "Y")
      ;;
    *)
      echo "Aborted."
      exit 1
      ;;
  esac

  echo "> Uninstalling Helm applications..."
  helm_uninstall minio
  helm_uninstall vvp
  helm_uninstall prometheus
  helm_uninstall grafana
  helm_uninstall elasticsearch
  helm_uninstall fluentd
  helm_uninstall kibana

  echo "> Deleting Kubernetes namespaces..."
  delete_namespaces
}

main
