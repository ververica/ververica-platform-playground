#!/usr/bin/env bash

set -o errexit
set -o nounset
set -o pipefail

HELM=${HELM:-helm}
HELM_VERSION=
VVP_CHART="ververica/ververica-platform"

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
  kubectl apply -f resources/namespaces.yaml
}

add_helm_repos() {
  $HELM repo add stable https://kubernetes-charts.storage.googleapis.com
  $HELM repo add ververica https://charts.ververica.com
}

install_minio() {
  if [ "$HELM_VERSION" -eq 2 ]; then
    $HELM install stable/minio \
      --name minio \
      --namespace minio \
      --values minio/values.yaml
  else
    $HELM --namespace minio \
      install minio stable/minio \
      --values minio/values.yaml
  fi
}

install_vvp() {
  if [ "$HELM_VERSION" -eq 2 ]; then
    $HELM install "$VVP_CHART" \
      --name vvp \
      --namespace vvp \
      --values ververica-platform/values.yaml \
      --values ververica-platform/values-license.yaml
  else
    $HELM --namespace vvp \
      install vvp "$VVP_CHART" \
      --values ververica-platform/values.yaml \
      --values ververica-platform/values-license.yaml
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
install_minio

echo "> Installing Ververica Platform..."
install_vvp
