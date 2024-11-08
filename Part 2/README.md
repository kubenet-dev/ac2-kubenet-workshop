# Autocon 2 - Kubenet Workshop - Part 2

## Overview
This second part of the workshop is mainly concerned with [SDCIO](https://docs.sdcio.dev/) (Schema Driven Configuration).

## Infrastructure setup

Following are the steps to setup the environment.

### Local Kubernetes cluster based on Kind

```shell
# pre-creating the kind docker bridge. This is to avoid an issue with kind running in codespaces. 
docker network create -d=bridge \
  -o com.docker.network.bridge.enable_ip_masquerade=true \
  -o com.docker.network.driver.mtu=1500 \
  --subnet fc00:f853:ccd:e793::/64 kind

# Allow the kind cluster to communicate with the later created containerlab topology
sudo iptables -I DOCKER-USER -o br-$(docker network inspect -f '{{ printf "%.12s" .ID }}' kind) -j ACCEPT

# creating the kind cluster
kind create cluster
```

```shell
# Load the local images into the kind cluster
kind load docker-image ghcr.io/sdcio/data-server:v0.0.48
kind load docker-image ghcr.io/sdcio/config-server:v0.0.41
```

### Nokia SRLinux based containerlab topology

```shell
# deploy Nokia SRL containers via containerlab
cd clab-topology
sudo containerlab deploy
```

### Install Cert-Manager

The config-server (extension api-server) requires a certificate, which is created via cert-manager. The corresponding CA cert needs to be injected into the cabundle spec field of the `api-service` resource.

```shell
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.13.3/cert-manager.yaml
# If the SDCIO resources, see below are being applied to fast, the webhook of the cert-manager is not already there.
# Hence we need to wait for the resource be become Available
kubectl wait -n cert-manager --for=condition=Available=True --timeout=300s deployments.apps cert-manager-webhook
```

## SDCIO

### Installation

```shell
# install sdcio
kubectl apply -f sdcio.yaml
```

Checking the api-registrations exist.

```shell
kubectl get apiservices.apiregistration.k8s.io | grep "sdcio.dev\|NAME"
```

The following two services should be `AVAILABLE == True`. This might take a second, since pods need to start and register themselfes.

```shell
NAME                                   SERVICE                        AVAILABLE   AGE
v1alpha1.config.sdcio.dev              network-system/config-server   True        16s
v1alpha1.inv.sdcio.dev                 Local                          True        16s
```

### Setup

```bash
# Nokia SR Linux Yang Schema
kubectl apply -f artifacts/schema-nokia-srl-24.7.2.yaml
# Connection Profile
kubectl apply -f artifacts/target-conn-profile-gnmi.yaml
# Sync Profile
kubectl apply -f artifacts/target-sync-profile-gnmi.yaml
# SRL Secret
kubectl apply -f artifacts/secret-srl.yaml
# Discovery Rule
kubectl apply -f artifacts/discovery_address.yaml
```
