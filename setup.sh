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
  echo "  -l, --with-logging"
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
  $HELM repo add kiwigrid https://kiwigrid.github.io
  $HELM repo add elastic https://helm.elastic.co
  $HELM repo add ververica https://charts.ververica.com
}

helm_install() {
  local name chart namespace

  name="$1"; shift
  chart="$1"; shift
  namespace="$1"; shift

  if [ "$HELM_VERSION" -eq 2 ]; then
    $HELM \
      upgrade --install "$name" "$chart" \
      --namespace $namespace \
      "$@"
  else
    $HELM \
      --namespace $namespace \
      upgrade --install "$name" "$chart" \
      "$@"
  fi
}

install_minio() {
  helm_install minio stable/minio vvp \
    --values values-minio.yaml
}

install_prometheus() {
  helm_install prometheus stable/prometheus vvp \
    --values values-prometheus.yaml
}

install_grafana() {
  helm_install grafana stable/grafana vvp \
    --values values-grafana.yaml \
    --set-file dashboards.default.flink-dashboard.json=grafana-dashboard.json
}

install_elasticsearch() {
  helm_install elasticsearch elastic/elasticsearch vvp \
    --values values-elasticsearch.yaml
}

install_fluentd() {
  helm_install fluentd kiwigrid/fluentd-elasticsearch vvp \
    --values values-fluentd.yaml
}

install_kibana() {
  helm_install kibana elastic/kibana vvp \
    --values values-kibana.yaml
}

helm_install_vvp() {
  helm_install vvp "$VVP_CHART" vvp \
    --values values-vvp.yaml \
    "$@"
}

install_vvp() {
  local edition install_metrics install_logging helm_additional_parameters

  edition="$1"
  install_metrics="$2"
  install_logging="$3"
  helm_additional_parameters=

  if [ -n "$install_metrics" ]; then
    helm_additional_parameters="${helm_additional_parameters} --values values-vvp-add-metrics.yaml"
  fi

  if [ -n "$install_logging" ]; then
    helm_additional_parameters="${helm_additional_parameters} --values values-vvp-add-logging.yaml"
  fi

  if [ "$edition" == "enterprise" ]; then
    helm_install_vvp \
      --values values-license.yaml \
      $helm_additional_parameters
  else
    # try installation once (aborts and displays license)
    helm_install_vvp $helm_additional_parameters

    read -r -p "Do you want to pass 'acceptCommunityEditionLicense=true'? (y/N) " yn

    case "$yn" in
      y|Y)
        helm_install_vvp \
          --set acceptCommunityEditionLicense=true \
          $helm_additional_parameters
        ;;
      *)
        echo "Ververica Platform installation aborted."
        exit 1
        ;;
    esac
  fi
}

main() {
  local edition install_metrics install_logging

  # defaults
  edition="community"
  install_metrics=
  install_logging=

  # parse params
  while [[ "$#" -gt 0 ]]; do case $1 in
    -e|--edition) edition="$2"; shift; shift;;
    -m|--with-metrics) install_metrics=1; shift;;
    -l|--with-logging) install_logging=1; shift;;
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

  if [ -n "$install_logging" ]; then
    echo "> Installing Elasticsearch..."
    install_elasticsearch || :

    echo "> Installing Fluentd..."
    install_fluentd || :

    echo "> Installing Kibana..."
    install_kibana || :
  fi

  echo "> Installing Ververica Platform..."
  install_vvp "$edition" "$install_metrics" "$install_logging" || :

  echo "> Waiting for all Deployments and Pods to become ready..."
  kubectl --namespace vvp wait --timeout=5m --for=condition=available deployments --all
  kubectl --namespace vvp wait --timeout=5m --for=condition=ready pods --all
}

main "$@"
