#!/usr/bin/env bash

HELM=helm

detect_helm_version() {

  HELM_VERSION_STRING=$($HELM version --short --client)

  if [[ "$HELM_VERSION_STRING" == *"v2"* ]]; then
    HELM_VERSION=2
  elif [[ "$HELM_VERSION_STRING" == *"v3"* ]]
  then
    HELM_VERSION=3
  else

    echo "Unsupported Helm version: $HELM_VERSION_STRING"

  fi
}

create_namespaces () {
  kubectl apply -f resources/namespaces.yaml
}

install_minio() {
  local helm_version=$1

  if [ "$helm_version" == 2 ]; then
    $HELM install stable/minio --name minio --namespace minio --values minio/values.yaml
  else
    $HELM install minio stable/minio --namespace minio --values minio/values.yaml
  fi
}

install_vvp() {
  local helm_version=$1

  $HELM repo add ververica https://charts.ververica.com

  if [ "$helm_version" == 2 ]; then
    $HELM install ververica/ververica-platform \
     --name vvp \
     --namespace vvp \
     --values ververica-platform/values.yaml \
     --values ververica-platform/values-license.yaml
  else
    $HELM install vvp ververica/ververica-platform \
     --namespace vvp \
     --values ververica-platform/values.yaml \
     --values ververica-platform/values-license.yaml
  fi
}

echo "Detecting Helm Version..."
detect_helm_version
echo "Helm Version is $HELM_VERSION."

echo "Creating Kubernetes Namespaces..."
create_namespaces

echo "Installing MinIO..."
install_minio $HELM_VERSION

echo "Installing Ververica Platform..."
install_vvp $HELM_VERSION
