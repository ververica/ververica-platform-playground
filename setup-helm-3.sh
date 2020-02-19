#!/usr/bin/env bash

HELM=helm

# Kubernetes Namespaces
kubectl apply -f resources/namespaces.yaml

# Minio
$HELM install minio stable/minio --namespace minio --values minio/values.yaml

# Ververica Platform
$HELM repo add ververica https://charts.ververica.com
$HELM install vvp ververica/ververica-platform --namespace vvp --values ververica-platform/values.yaml
