#!/usr/bin/env bash

set -o errexit
set -o nounset
set -o pipefail

HELM=${HELM:-helm}
HELM_VERSION=
VVP_CHART="ververica/ververica-platform"


usage() {
    echo -e "This script installs Ververica Platform as well as its dependencies into a Kubernetes cluster using Helm. \n"
    echo "./setup.sh"
    echo -e "\t -h --help"
    echo -e "\t -e --edition [community|stream] (default: commmunity)"
}

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

  $HELM repo add ververica https://charts.ververica.com

  if [ "$vvp_edition" == "stream" ]; then
    if [ "$HELM_VERSION" -eq 2 ]; then
      $HELM install $VVP_CHART \
       --name vvp \
       --namespace vvp \
       --values ververica-platform/values.yaml \
       --values ververica-platform/values-license.yaml
    else
      $HELM install vvp $VVP_CHART \
       --namespace vvp \
       --values ververica-platform/values.yaml \
       --values ververica-platform/values-license.yaml
    fi
  else
    if [ "$HELM_VERSION" -eq 2 ]; then
      $HELM install $VVP_CHART \
       --name vvp \
       --namespace vvp \
       --values ververica-platform/values.yaml

      read -r -p "Do you want to pass 'acceptCommunityEditionLicense=true'? (Y/N) " yn

      case $yn in
           "Y")
            $HELM install $VVP_CHART \
             --name vvp \
             --namespace vvp \
             --values ververica-platform/values.yaml \
             --set acceptCommunityEditionLicense=true
            ;;
           *)
            echo "Ververica Platform installation aborted."
            exit 1
            ;;
      esac

    else
      $HELM install vvp $VVP_CHART \
       --namespace vvp \
       --values ververica-platform/values.yaml

      read -r -p "Do you want to pass 'acceptCommunityEditionLicense=true'? (Y/N) " yn

      case $yn in
           "Y")
             $HELM install vvp $VVP_CHART \
             --namespace vvp \
             --values ververica-platform/values.yaml \
             --set acceptCommunityEditionLicense=true
            ;;
           *)
            echo "Ververica Platform installation aborted."
            exit 1
            ;;
      esac

    fi
  fi
}

########
# Main #
########

EDITION=community #default value

while [ "$1" != "" ]; do

    case $1 in
        -h | --help)
          usage
          exit
          ;;
        -e | --edition)
          EDITION="$2"
          case $EDITION in
              "stream"|"community")
                ;;
              *)
                echo -e "ERROR: unknown edition \"$EDITION\" \n"
                usage
                exit 1
          esac
          shift
          shift
          ;;
        *)
          echo -e "ERROR: unknown parameter \"$1\" \n"
          usage
          exit 1
          ;;
    esac
done

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
