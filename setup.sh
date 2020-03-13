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

create_namespaces() {
  # Create namespace `vvp` and `vvp-jobs` if they do not exist
  kubectl get namespace vvp > /dev/null 2>&1 || kubectl create namespace vvp
  kubectl get namespace vvp-jobs > /dev/null 2>&1 || kubectl create namespace vvp-jobs
}

add_helm_repos() {
  $HELM repo add stable https://kubernetes-charts.storage.googleapis.com
  $HELM repo add ververica https://charts.ververica.com
}

install_minio() {
  if [ "$HELM_VERSION" -eq 2 ]; then
    $HELM install stable/minio \
      --name minio \
      --namespace vvp \
      --values values-minio.yaml
  else
    $HELM --namespace vvp \
      install minio stable/minio \
      --values values-minio.yaml
  fi
}

install_vvp() {
  if [ "$HELM_VERSION" -eq 2 ]; then
    $HELM install ververica/ververica-platform \
      --name vvp \
      --namespace vvp \
      --values values-vvp.yaml \
      --values values-license.yaml
  else
    $HELM --namespace vvp \
      install vvp ververica/ververica-platform \
      --values values-vvp.yaml \
      --values values-license.yaml
  fi
}

echo -n "> Detecting Helm version... "
detect_helm_version
echo "detected Helm ${HELM_VERSION}."

echo "> Creating Kubernetes namespaces..."
create_namespaces

echo "> Adding Helm chart repositories..."
add_helm_repos

echo "> Installing MinIO..."
install_minio || :

echo "> Installing Ververica Platform..."
install_vvp || :
