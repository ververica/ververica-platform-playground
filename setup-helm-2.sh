#!/usr/bin/env bash

HELM=helm

# Kubernetes Namespaces
kubectl apply -f resources/namespaces.yaml

# Minio
$HELM install stable/minio --name minio --namespace minio --values minio/values.yaml

# Ververica Platform
$HELM install ververica-platform-2.0.4.tgz --name vvp --namespace vvp -values ververica-platform/values.yaml