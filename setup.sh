#!/usr/bin/env bash

HELM=helm
VVP_CHART="ververica/ververica-platform"

usage() {
    echo -e "This script installs Ververica Platform as well as its dependencies into a Kubernetes cluster using Helm. \n"
    echo "./setup.sh"
    echo -e "\t -h --help"
    echo -e "\t -e --edition [community|stream] (default: commmunity)"
}

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
  local vvp_edition=$2

  $HELM repo add ververica https://charts.ververica.com

  if [ "$vvp_edition" == "stream" ]; then
    if [ "$helm_version" == 2 ]; then
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
    if [ "$helm_version" == 2 ]; then
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

echo "Detecting Helm Version..."
detect_helm_version
echo "Helm Version is $HELM_VERSION."

echo "Creating Kubernetes Namespaces..."
create_namespaces

echo "Installing MinIO..."
install_minio "$HELM_VERSION"

echo "Installing Ververica Platform ($EDITION)..."
install_vvp "$HELM_VERSION" "$EDITION"
