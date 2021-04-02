#!/usr/bin/env bash

set -o errexit
set -o nounset
set -o pipefail

HELM=${HELM:-helm}

VVP_NAMESPACE=${VVP_NAMESPACE:-vvp}
JOBS_NAMESPACE=${JOBS_NAMESPACE:-"vvp-jobs"}

helm_uninstall() {
  local release
  release="$1"

  if [ -z "$release" ]; then
    echo >&2 "error: release is required"
    return 1
  fi

  $HELM --namespace "$VVP_NAMESPACE" delete "$release" 2>/dev/null || :
}

uninstall_prometheus_operator() {
  helm_uninstall prometheus-operator
  # Prometheus Operator CRDs must also be deleted (which will also delete the resources in prometheus-operator-resources)
  kubectl get crds | grep monitoring.coreos.com  | tr -s " " | cut -d " " -f1 | xargs kubectl delete crd || :
}

delete_namespaces() {
  kubectl get namespace "$VVP_NAMESPACE" > /dev/null 2>&1 && kubectl delete namespace "$VVP_NAMESPACE" || :
  kubectl get namespace "$JOBS_NAMESPACE" > /dev/null 2>&1 && kubectl delete namespace "$JOBS_NAMESPACE" || :
}

main() {
  local kube_context
  kube_context="$(kubectl config current-context)"

  echo -n "This script will delete all playground components and the '$VVP_NAMESPACE' and "
  echo "'$JOBS_NAMESPACE' namespaces from Kubernetes."
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
  uninstall_prometheus_operator
  helm_uninstall grafana
  helm_uninstall elasticsearch
  helm_uninstall fluentd
  helm_uninstall kibana

  echo "> Deleting Kubernetes namespaces..."
  delete_namespaces
}

main
