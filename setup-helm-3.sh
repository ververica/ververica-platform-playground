#!/usr/bin/env bash

HELM=helm

# Kubernetes Namespaces
kubectl apply -f resources/namespaces.yaml

# Minio
$HELM install minio stable/minio --namespace minio --values minio/values.yaml

# Ververica Platform
$HELM install vvp ververica-platform-2.0.4.tgz --namespace vvp --values ververica-platform/values.yaml
