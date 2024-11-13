# Autocon 2 - Kubenet Workshop - Part 2

## Overview

This second part of the workshop is mainly concerned with [SDC](https://docs.sdcio.dev/) (Schema Driven Configuration).

## Infrastructure setup

Following are the steps to setup the environment.

```shell
# change into Part 2 directory
cd /workspaces/ac2-kubenet-workshop/Part\ 2/
```

### Load pre-cached container images

```shell
# import the locally cached sr-linux container image
docker image load -i /var/cache/srlinux.tar

# import the locally cached kind node container image
docker image load -i /var/cache/kindest-node.tar
```

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
kind load image-archive /var/cache/data-server.tar
kind load image-archive /var/cache/config-server.tar
```

### Nokia SRLinux based containerlab topology

```shell
# deploy Nokia SRL containers via containerlab
cd clab-topology
sudo containerlab deploy
cd -
```

### Install Cert-Manager

The config-server (extension api-server) requires a certificate, which is created via cert-manager. The corresponding CA cert needs to be injected into the cabundle spec field of the `api-service` resource.

```shell
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.13.3/cert-manager.yaml
# If the SDCIO resources, see below are being applied to fast, the webhook of the cert-manager is not already there.
# Hence we need to wait for the resource be become Available
kubectl wait -n cert-manager --for=condition=Available=True --timeout=300s deployments.apps cert-manager-webhook
```

## SDC

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

```shell
# inspect the different artifact files
batcat artifacts/*
```

```shell
# Nokia SR Linux Yang Schema
kubectl apply -f artifacts/schema-nokia-srl-24.7.2.yaml
```

Verify that the schema is downloaded and ready to be used.

```shell 
> kubectl get schemas.inv.sdcio.dev srl.nokia.sdcio.dev-24.7.2
NAME                         READY   PROVIDER              VERSION   URL                                            REF
srl.nokia.sdcio.dev-24.7.2   True    srl.nokia.sdcio.dev   24.7.2    https://github.com/nokia/srlinux-yang-models   v24.7.2
```

```shell
# Connection Profile
kubectl apply -f artifacts/target-conn-profile-gnmi.yaml

# Sync Profile
kubectl apply -f artifacts/target-sync-profile-gnmi.yaml

# SRL Secret
kubectl apply -f artifacts/secret-srl.yaml

# Discovery Rule
kubectl apply -f artifacts/discovery_address.yaml
```

As a result of the discovery rule you shoud now see two targets created.
The discovery will also determine additional information like the Platform, Serial number and chassis MAC address.

```shell
> kubectl get targets.inv.sdcio.dev 
NAME   READY   REASON   PROVIDER              ADDRESS        PLATFORM       SERIALNUMBER     MACADDRESS
dev1   True             srl.nokia.sdcio.dev   172.21.0.200   7220 IXR-D2L   Sim Serial No.   1A:EB:00:FF:00:00
dev2   True             srl.nokia.sdcio.dev   172.21.0.201   7220 IXR-D2L   Sim Serial No.   1A:F8:01:FF:00:00
```

### Usage

#### Retrieve Configuration

```shell
kubectl get runningconfigs.config.sdcio.dev dev1 -o yaml
```

The output is quite extensive so lets just take a look at the network-instance configuration.

```shell
kubectl get runningconfigs.config.sdcio.dev dev1 -o jsonpath="{.status.value.network-instance}" | jq
```

#### Apply Configuration


Verify interface config for interface `system0`.

```shell
# via docker
docker exec dev1 sr_cli "info interface system0"

# or via ssh 
ssh dev1 "info interface system0"
```

This will result in no output, since the interface `system0` is not yet configure.
So let's get to it.

```shell
batcat configs/system0.yaml
kubectl apply -f configs/system0.yaml
```

verify that the config is properly applied.

```shell
> kubectl get configs.config.sdcio.dev
NAME           READY   REASON   TARGET         SCHEMA
dev1-system0   False   Failed   default/dev1   
```
You will see the resource is not `READY`, it failed to apply.

Let's investigate why that is.

```shell
# either reference by name
kubectl get configs.config.sdcio.dev dev1-system0 -o yaml
# or via the filename again
kubectl get -f configs/system0.yaml -o yaml
```

```json
...
status:
  conditions:
  - lastTransitionTime: "2024-11-11T13:57:36Z"
    message: 'rpc error: code = Unknown desc = value "shutdown" does not match enum
      type "admin-state", must be one of [disable, enable]'
    reason: Failed
    status: "False"
    type: Ready
```

The data-server indicated, that for the `admin-state` field, the allowed values are either `enable` or `disable`. These allowed field values it did take from the schema, that defined the allowed value space.

Lets set the value to `disable`.

```shell
kubectl apply -f configs/system0_disable.yaml
```

Lets check the status again.
```shell
# either reference by name
kubectl get configs.config.sdcio.dev dev1-system0 -o yaml
# or via the filename again
kubectl get -f configs/system0_disable.yaml -o yaml
```

```json
...
status:
  appliedConfig:
    config:
    - path: /
      value:
        interface:
        - admin-state: disable
          description: Ethernet-1/3 Interface Description
          name: ethernet-1/3
    lifecycle: {}
    priority: 10
  conditions:
  - lastTransitionTime: "2024-11-11T14:19:51Z"
    message: |-
      rpc error: code = Unknown desc = cumulated validation errors:
      error must-statement ["((. = 'enable') and starts-with(../srl_nokia-if:name, 'system0')) or not(starts-with(../srl_nokia-if:name, 'system0'))"] path: interface/system0/admin-state: admin-state must be enable
    reason: Failed
    status: "False"
    type: Ready
```

Now we hit a must-statement, also a YANG construct, that allows to define fine grained rules on field in the configuration. The must statement is even provided as part of the output.

```
"((. = 'enable') and starts-with(../srl_nokia-if:name, 'system0')) or not(starts-with(../srl_nokia-if:name, 'system0'))"
```

Now that we now, system0 must always be up, we can set its admin-state to up and config will be applied.

Lets set the value to `enable`.

```shell
kubectl apply -f configs/system0_enable.yaml
```

Verify that configs status.

```shell
> kubectl get configs.config.sdcio.dev 
NAME           READY   REASON   TARGET         SCHEMA
dev1-system0   True    Ready    default/dev1   srl.nokia.sdcio.dev/24.7.2
```

Verify on the device, that the config is applied 

```shell
docker exec dev1 sr_cli "info interface system0"
```


#### Apply ConfigSet

Verify interface config for ethernet-1/1 and ethernet-1/2.

```shell
# via docker
docker exec dev1 sr_cli "info interface ethernet-1/{1,2}"

# or via ssh 
ssh dev1 "info interface ethernet-1/{1,2}"
```

Notice no Vlans are actually configure.
Now take a look at `configs/vlans.yaml` and apply it.

```shell
batcat configs/vlans.yaml
kubectl apply -f configs/vlans.yaml
```

Verify device config again with the afore mentioned command.

Change the `configs/vlans.yaml` file. Change `ethernet-1/1` to `ethernet-1/2`.
If you like add or remove vlans, descriptions, whatever and reapply the config.

```shell
kubectl apply -f configs/vlans.yaml
```

The device config should reflect the changes. It will have removed the initial config and applied your actual changes.

The ConfigSet reconciler takes the ConfigSet definition and creates configs for all the targets that match the targetSelector []. 

The changes can be verified via above commands again, but also via kubernetes itself:

```shell
kubectl get runningconfigs.config.sdcio.dev dev1 -o jsonpath="{.status.value.interface}" | jq
## or more specific again just ethernet-1/1 and ethernet-1/2
kubectl get runningconfigs.config.sdcio.dev dev1 -o jsonpath='{.status.value.interface}' | jq '.[] | select(.name | test("ethernet-1/{1,2}"))'
```


### How to generate yaml config snippets on SRLinux

1. login to the container
   
   ```shell
   # ssh
   ssh dev1
   # or via docker
   docker exec -it dev1 sr_cli
   ```

2. build sample config on device
   
    ```shell
    # enter configuration context
    > enter candidate
    
    # change config
    > set interface ethernet-1/3 description "MyDescription"
    
    # show diff in yaml format
    > diff | as yaml
    + interface:
    +   - name: ethernet-1/3
    +     description: MyDescription

    # NOTE: plus signes need ot be removed, but that is the actual yaml based config of the change.

    # use discard now to discard changes, to make them apply via k8s
    > discard now
    ```

3. build k8s resource 

    ```yaml
    apiVersion: config.sdcio.dev/v1alpha1
    kind: Config
    metadata:
      name: MyIntent                << Adjust Intenet Name 
      namespace: default
    spec:
      priority: 10
      config:
      - path: /
        value:
          <INSERT CONFIG HERE>
    ```
