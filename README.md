# Ververica Platform Playground

Welcome to the Ververica Platform Playground!

## Setting the Stage

### helm

*"Helm helps you manage Kubernetes applications — Helm Charts help you define, install, and upgrade even the most 
complex Kubernetes application."*

Ververica Platform also comes in the form of a Helm Chart. Please check out For details check 
https://helm.sh/docs/intro/install/ for installation introduction.
For convenience, we list some common options below. 

#### Installation on Mac OS (homebrew)

```
brew install helm
```

##### Installation on Windows (Chocolatey) 

```
choco install kubernetes-helm
```

##### Installation on Linux

There is a package available for most package managers. For details check https://helm.sh/docs/intro/install/ or search 
your packager manager.

### Minikube & Kubernetes CLI

Ververica Platform runs on top of Kubernetes. In order to get started locally we recommend using `minikube`, but any 
other Kubernetes Cluster (1.11+) will do, too. 
 
Minikube relies on virtualization support by your operating system as well as a hypervisor (e.g. Virtualbox). Please 
check https://kubernetes.io/docs/tasks/tools/install-minikube/#before-you-begin for details.  

#### Installation on Mac OS (homebrew)

```
brew install kubectl minikube
```

##### Installation on Windows (Chocolatey) 

```
choco install kubernetes-cli minikube
```

##### Installation on Linux

As before there are packages available for most package manager. Please check 
https://kubernetes.io/docs/tasks/tools/install-kubectl/#install-kubectl-on-linux (Kubernetes CLI) and 
https://kubernetes.io/docs/tasks/tools/install-minikube/ (Minikube) for details. 



## Getting Started with Ververica Platform





