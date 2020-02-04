# Welcome to the Ververica Platform Playground

In this playground, you will install Ververica Platform, integrate it with Minio for 
[Universal Blob Storage](https://docs.ververica.com/administration/blob_storage.html), and create your first Apache Flink 
application using Ververica Platform.

* [Setting the Stage](#setting-the-stage)
  + [Kubernetes](#kubernetes)
  + [helm](#helm)
* [Setting Up the Playground](#setting-up-the-playground)
  + [Anatomy of this Playground](#anatomy-of-this-playground)
  + [Installing the Components](#installation)
* [Cleaning Up](#teardown)
* [About](#about)

## Setting the Stage

### Kubernetes

Ververica Platform runs on top of Kubernetes. In order to get started locally we recommend using `minikube`, but any 
other Kubernetes Cluster (1.11+) will do, too. 
 
Minikube relies on virtualization support by your operating system as well as a hypervisor (e.g. Virtualbox). Please 
check [the official installation guide](https://kubernetes.io/docs/tasks/tools/install-minikube/#before-you-begin) for details.  

#### Minikube on Mac OS (homebrew)

```
brew install kubectl minikube
```

#### Minikube on Windows (Chocolatey) 

```
choco install kubernetes-cli minikube
```

#### Minikube on Linux

There are packages available for most distros and package managers. Please check 
the [kubectl installation guide](https://kubernetes.io/docs/tasks/tools/install-kubectl/#install-kubectl-on-linux) as 
well as the [minikube installation guide](https://kubernetes.io/docs/tasks/tools/install-minikube/#install-minikube) for details. 

#### Spinning up a Kubernetes Cluster

First, you start `minikube`. The platform (including a small Apache Flink application) requires at least 8G of memory 
and 4 CPUs.  

```
minikube start --memory=8G --cpus=4
```

If this went well, you can continue and check if all system pods are ready.

```
kubectl get pods -n kube-system
``` 

Depending on your exact version of minikube, the output should look more or less similar to

```
NAME                               READY   STATUS    RESTARTS  AGE
coredns-5644d7b6d9-56zhg           1/1     Running   1         2m
coredns-5644d7b6d9-fdnts           1/1     Running   1         2m
etcd-minikube                      1/1     Running   1         2m
kube-addon-manager-minikube        1/1     Running   1         2m
kube-apiserver-minikube            1/1     Running   1         2m
kube-controller-manager-minikube   1/1     Running   1         2m
kube-proxy-9w92r                   1/1     Running   1         2m
kube-scheduler-minikube            1/1     Running   1         2m
storage-provisioner                1/1     Running   2         2m
```

If all pods are ready, you are good to go. 

### helm

*"Helm helps you manage Kubernetes applications — Helm Charts help you define, install, and upgrade even the most 
complex Kubernetes application."* - [helm.sh](https://helm.sh/)

We as well decided to distribute Ververica Platform as a Helm Chart. To install helm please follow the instructions on  
the [official installation guide](https://helm.sh/docs/intro/install/) or use one of the one-liners below.

**Note:** This playground assumes Helm 3.x. When using Helm 2.x, you need to setup Tiller in your Kubernetes cluster
and commands will be slightly different.

#### Helm on Mac OS (homebrew)

```
brew install helm
```

#### Helm on Windows (Chocolatey) 

```
choco install kubernetes-helm
```

#### Helm on Linux

As before, there is a package available for most distros and package managers. For details check the 
[official installation guide](https://helm.sh/docs/intro/install/).

#### Verifying Helm Installation

After installation `helm list` should return an empty list without any errors.  

## Setting Up the Playground

### Anatomy of this Playground

For this playground, you will create three Kubernetes namespaces: `vvp`, `vvp-jobs` and `minio`. `vvp` will host the 
control plane of Ververica  Platform while the actual Apache Flink deployments will run in the `vvp-jobs` namespace. 
Additionally, we will setup [MinIO](https://min.io/) in a separate namespace, which is used for artifact storage as well 
as Apache Flink checkpoints & savepoints 
([Universal Blob Storage](https://docs.ververica.com/administration/blob_storage.html)). 

```
+--------------------------------+           +--------------------------------+                     
|        namespace: minio        |           |         namespace: vvp         |                     
|                                |           |                                |                     
|        +--------------+        | Artifacts |        +--------------+        |                     
|        |              |        |-----------|        |              |        |                     
|        |    Minio     |        |           |        |  Ververica   |        |                     
|        |              |        |           |        |  Platform    |        |                     
|        +--------------+        |           |        |              |        |                     
|                                |           |        +--------------+        |                     
+--------------------------------+           +--------------------------------+                     
                   \--                                        |                                     
                      \--                                     |Management of Apache Flink Deployment
                         \--                                  |                                     
                            \-               +--------------------------------+                     
                              \--            |      namespace: vvp-jobs       |                     
        Checkpoints/Savepoints   \--         |                                |                     
                                    \--      |        +--------------+        |                     
                                       \--   |        |              |        |                     
                                          \- |        | Apache Flink |        |                     
                                             |        |   Clusters   |        |                     
                                             |        |              |        |                     
                                             |        +--------------+        |                     
                                             +--------------------------------+   
```

### Installing the Components

#### TL;DR:

You can skip all of the installation steps outlined below by running 

```
./setup.sh
```

#### Kubernetes Namespaces

Before installing any of the components you need the underlying Kubernetes namespaces.

```
kubectl apply -f resources/namespaces.yaml
```

#### MinIO

First, you install MinIO using `helm`. For MinIO, you can use the official Helm chart, for which you might first need to 
add the `stable` Helm repository.

```
# helm repo add stable http://storage.googleapis.com/kubernetes-charts
helm install minio stable/minio --namespace minio --values minio/values.yaml
```

#### Ververica Platform 

Second, you can install Ververica Platform again using `helm`. 
 
```
helm install vvp ververica-platform-2.0.4.tgz --namespace vvp --values ververica-platform/values.yaml
```

In order to access the web user interface or the REST API setup a port forward to the Ververica Platform Kubernetes 
service.

```
kubectl port-forward --namespace vvp service/vvp-ververica-platform 8080:80
```

Both interfaces are now available under `localhost:8080`. 

## Cleaning Up

```
kubectl delete namespace minio vvp vvp-jobs
```

## About

[Ververica Platform](https://www.ververica.com) is the enterprise stream processing platform by the original creators of [Apache Flink](https://flink.apache.org/). 
