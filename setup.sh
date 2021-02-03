#!/usr/bin/env bash

set -o errexit
set -o nounset
set -o pipefail

HELM=${HELM:-helm}
VVP_CHART=${VVP_CHART:-}

VVP_NAMESPACE=${VVP_NAMESPACE:-vvp}
JOBS_NAMESPACE=${JOBS_NAMESPACE:-"vvp-jobs"}

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

create_namespaces() {
  # Create the vvp system and jobs namespaces if they do not exist
  kubectl get namespace "$VVP_NAMESPACE" > /dev/null 2>&1 || kubectl create namespace "$VVP_NAMESPACE"
  kubectl get namespace "$JOBS_NAMESPACE" > /dev/null 2>&1 || kubectl create namespace "$JOBS_NAMESPACE"
}

helm_install() {
  local name chart namespace

  name="$1"; shift
  chart="$1"; shift
  namespace="$1"; shift

  $HELM \
    --namespace "$namespace" \
    upgrade --install "$name" "$chart" \
    "$@"
}

install_minio() {
  helm_install minio minio "$VVP_NAMESPACE" \
    --repo https://helm.min.io \
    --values values-minio.yaml
}

install_prometheus() {
  helm_install prometheus prometheus "$VVP_NAMESPACE" \
    --repo https://prometheus-community.github.io/helm-charts \
    --values values-prometheus.yaml
}

install_grafana() {
  helm_install grafana grafana "$VVP_NAMESPACE" \
    --repo https://grafana.github.io/helm-charts \
    --values values-grafana.yaml \
    --set-file dashboards.default.flink-dashboard.json=grafana-dashboard.json
}

install_elasticsearch() {
  helm_install elasticsearch elasticsearch "$VVP_NAMESPACE" \
    --repo https://helm.elastic.co \
    --values values-elasticsearch.yaml
}

install_fluentd() {
  helm_install fluentd fluentd-elasticsearch "$VVP_NAMESPACE" \
    --repo https://kokuwaio.github.io/helm-charts \
    --values values-fluentd.yaml
}

install_kibana() {
  helm_install kibana kibana "$VVP_NAMESPACE" \
    --repo https://helm.elastic.co \
    --values values-kibana.yaml
}

helm_install_vvp() {
  if [ -n "$VVP_CHART" ];  then
    helm_install vvp "$VVP_CHART" "$VVP_NAMESPACE" \
      --values values-vvp.yaml \
      "$@"
  else
    helm_install vvp ververica-platform "$VVP_NAMESPACE" \
      --repo https://charts.ververica.com \
      --values values-vvp.yaml \
      "$@"
  fi
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

  echo "> Creating Kubernetes namespaces..."
  create_namespaces

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
  kubectl --namespace "$VVP_NAMESPACE" wait --timeout=5m --for=condition=available deployments --all
  kubectl --namespace "$VVP_NAMESPACE" wait --timeout=5m --for=condition=ready pods --all
}

main "$@"
