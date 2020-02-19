#!/usr/bin/env bash

HELM=helm

# Kubernetes Namespaces
kubectl apply -f resources/namespaces.yaml

# Minio
$HELM install stable/minio --name minio --namespace minio --values minio/values.yaml

# Ververica Platform
$HELM repo add ververica https://charts.ververica.com
$HELM install ververica/ververica-platform --name vvp --namespace vvp -values ververica-platform/values.yaml