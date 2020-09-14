#!/usr/bin/env bash

set -o errexit
set -o nounset
set -o pipefail

HELM=${HELM:-helm}
HELM_VERSION=
VVP_CHART=${VVP_CHART:-ververica/ververica-platform}

usage() {
  echo "This script installs Ververica Platform as well as its dependencies into a Kubernetes cluster using Helm."
  echo
  echo "Usage:"
  echo "  $0 [flags]"
  echo
  echo "Flags:"
  echo "  -h, --help"
  echo "  -e, --edition [community|enterprise] (default: commmunity)"
  echo "  -m, --with-metrics"
}

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

create_namespaces() {
  # Create namespace `vvp` and `vvp-jobs` if they do not exist
  kubectl get namespace vvp > /dev/null 2>&1 || kubectl create namespace vvp
  kubectl get namespace vvp-jobs > /dev/null 2>&1 || kubectl create namespace vvp-jobs
}

add_helm_repos() {
  $HELM repo add stable https://kubernetes-charts.storage.googleapis.com
  $HELM repo add ververica https://charts.ververica.com
  $HELM repo add minio https://helm.min.io/
}

install_minio() {
  if [ "$HELM_VERSION" -eq 2 ]; then
    $HELM install minio/minio \
      --name minio \
      --namespace vvp \
      --values values-minio.yaml
  else
    $HELM --namespace vvp \
      install minio minio/minio \
      --values values-minio.yaml
  fi
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

install_vvp() {
  local edition install_metrics vvp_values_file

  edition="$1"
  install_metrics="$2"

  if [ -n "$install_metrics" ]; then
    vvp_values_file="values-vvp-with-metrics.yaml"
  else
    vvp_values_file="values-vvp.yaml"
  fi

  if [ "$edition" == "enterprise" ]; then
    if [ "$HELM_VERSION" -eq 2 ]; then
      $HELM install "$VVP_CHART" \
        --name vvp \
        --namespace vvp \
        --values "$vvp_values_file" \
        --values values-license.yaml
    else
      $HELM --namespace vvp \
        install vvp "$VVP_CHART" \
        --values "$vvp_values_file" \
        --values values-license.yaml
    fi
  else
    if [ "$HELM_VERSION" -eq 2 ]; then
      $HELM install "$VVP_CHART" \
        --name vvp \
        --namespace vvp \
        --values "$vvp_values_file"
    else
      $HELM --namespace vvp \
        install vvp "$VVP_CHART" \
        --values "$vvp_values_file"
    fi

    read -r -p "Do you want to pass 'acceptCommunityEditionLicense=true'? (Y/n) " yn

    case $yn in
      "Y")
        if [ "$HELM_VERSION" -eq 2 ]; then
          $HELM install "$VVP_CHART" \
            --name vvp \
            --namespace vvp \
            --values "$vvp_values_file" \
            --set acceptCommunityEditionLicense=true
        else
          $HELM --namespace vvp \
            install vvp "$VVP_CHART" \
            --values "$vvp_values_file" \
            --set acceptCommunityEditionLicense=true
        fi
        ;;
      *)
        echo "Ververica Platform installation aborted."
        exit 1
        ;;
    esac
  fi
}

main() {
  local edition install_metrics

  # defaults
  edition="community"
  install_metrics=

  # parse params
  while [[ "$#" -gt 0 ]]; do case $1 in
    -e|--edition) edition="$2"; shift; shift;;
    -m|--with-metrics) install_metrics=1; shift;;
    -h|--help) usage; exit;;
    *) usage ; exit 1;;
  esac; done

  # verify params
  case $edition in
    "enterprise"|"community")
      ;;
    *)
      echo "ERROR: unknown edition \"$edition\""
      echo
      usage
      exit 1
  esac

  echo -n "> Detecting Helm version... "
  HELM_VERSION="$(detect_helm_version)"
  echo "detected Helm ${HELM_VERSION}."

  echo "> Creating Kubernetes namespaces..."
  create_namespaces

  echo "> Adding Helm chart repositories..."
  add_helm_repos

  echo "> Installing MinIO..."
  install_minio || :

  if [ -n "$install_metrics" ]; then
    echo "> Installing Prometheus..."
    install_prometheus || :

    echo "> Installing Grafana..."
    install_grafana || :
  fi

  echo "> Installing Ververica Platform..."
  install_vvp "$edition" "$install_metrics" || :
}

main "$@"
