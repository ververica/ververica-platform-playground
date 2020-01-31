# Welcome to the Ververica Platform Playground

In this playground, you will install Ververica Platform, integrate it with Minio for Universal Blob Storage and create
your first Apache Flink application using Ververica Platform.

## Setting the Stage

### Kubernetes

Ververica Platform runs on top of Kubernetes. In order to get started locally we recommend using `minikube`, but any 
other Kubernetes Cluster (1.11+) will do, too. 
 
Minikube relies on virtualization support by your operating system as well as a hypervisor (e.g. Virtualbox). Please 
check https://kubernetes.io/docs/tasks/tools/install-minikube/#before-you-begin for details.  

#### Minikube on Mac OS (homebrew)

```
brew install kubectl minikube
```

#### Minikube on Windows (Chocolatey) 

```
choco install kubernetes-cli minikube
```

#### Minikube on Linux

There are packages available for most package manager. Please check 
https://kubernetes.io/docs/tasks/tools/install-kubectl/#install-kubectl-on-linux (Kubernetes CLI) and 
https://kubernetes.io/docs/tasks/tools/install-minikube/ (Minikube) for details. 

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
complex Kubernetes application."*

We as well decided to distribute Ververica Platform as a Helm Chart. To  install helm please follow the instructions on  
https://helm.sh/docs/intro/install/ or use one of the one-liners below.

#### Helm on Mac OS (homebrew)

```
brew install helm
```

#### Helm on Windows (Chocolatey) 

```
choco install kubernetes-helm
```

#### Helm on Linux

As before, there is a package available for most package managers. For details check https://helm.sh/docs/intro/install/ or search 
your packager manager.

#### Verifying Helm Installation

After installation `helm list` should return an empty list (You did not install anything yet.) successfully.  

## Getting Started with Ververica Platform

Now, we can install Ververica Platform using `helm`. 
 
```
helm install \
  --name vvp \
  --values ververica-platform/values.yaml \
  ververica-platform-2.0.3.tgz
```

In order to access the web user interface or the REST API, you need to setup a port forward to the Ververica Platform 
Kubernetes service.

```
kubectl port-forward service/vvp-ververica-platform 8080:80
```

The web user interface is now available under `localhost:8080`. 

