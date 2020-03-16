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

create_namespace() {
  # Create namespace `vvp` if it doesn't exist
  kubectl get namespace vvp > /dev/null 2>&1 || kubectl create namespace vvp
}

add_helm_repo() {
  $HELM repo add stable https://kubernetes-charts.storage.googleapis.com
}

install_prometheus() {
  if [ "$HELM_VERSION" -eq 2 ]; then
    $HELM install stable/prometheus \
      --name prometheus \
      --namespace vvp \
      --values values-prometheus.yaml
  else
    $HELM --namespace vvp \
      install prometheus stable/prometheus \
      --values values-prometheus.yaml
  fi
}

install_grafana() {
  if [ "$HELM_VERSION" -eq 2 ]; then
    $HELM install stable/grafana \
      --name grafana \
      --namespace vvp \
      --values values-grafana.yaml \
      --set-file dashboards.default.flink-dashboard.json=grafana-dashboard.json
  else
    $HELM --namespace vvp \
      install grafana stable/grafana \
      --values values-grafana.yaml \
      --set-file dashboards.default.flink-dashboard.json=grafana-dashboard.json
  fi
}

echo -n "> Detecting Helm version... "
detect_helm_version
echo "detected Helm ${HELM_VERSION}."

echo "> Creating Kubernetes namespace..."
create_namespace

echo "> Adding Helm chart repository..."
add_helm_repo

echo "> Installing Prometheus..."
install_prometheus || :

echo "> Installing Grafana..."
install_grafana || :
