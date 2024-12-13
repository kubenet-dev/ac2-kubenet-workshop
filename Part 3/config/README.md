# Config example

The goal of this exercise is to show you the basics of choreo (and kubernetes principles) through a config example. We will show how to create an updated a device config from an abstracted intent.

- introduces:
  - see hello-world/topology for earlier concepts
  - watch resource
  - dependencies using conditions
  - jinja2 templates
  - additional builtin functions
  - YANG schemas

## Getting started

Move your working directory to the `ac2-kubenet-workshop/Part 3` subdirectory

## Explore the project

### CRDs

No local crds are referenced, but we have 3 references that import crds. This allows for reusable code. There is 2 types of references in choreo:
- crd based: only import crds -> we call this a crd child instance
- all: import everything (right now we only support 2 hierarchies of all refs) - root -> single root child 

### Input

The input directory where your input manifest are located

```shell
cat config/in/ipam.be.kuid.dev.ipindex.kubenet.default.yaml
cat config/in/infra.kuid.dev.node.kubenet.region1.us-east.node1.yaml
```

One is an IP Pool from which we can draw IPs, the 2nd is a node inventory object representing a network device.

[ip pool input](https://raw.githubusercontent.com/kubenet-dev/ac2-kubenet-workshop/refs/heads/main/Part%203/config/in/ipam.be.kuid.dev.ipindex.kubenet.default.yaml)

[node input](https://raw.githubusercontent.com/kubenet-dev/ac2-kubenet-workshop/refs/heads/main/Part%203/config/in/infra.kuid.dev.node.kubenet.region1.us-east.node1.yaml)

### Reconcilers

The directory where the reconcilers are located (`reconcilers`). Each reconciler is located in its own directory with a reconciler config and reconciler logic.

Besides the starlark (python) reconciler types we now also have jinja2 based reconcilers. We use them to transform the abstract resources to device specific configuration.

In the reconcilers we now also use the watch resource to trigger the event logic on changes to the watch resources.We use conditions for dependency management.

The following reconcilers are present:

- `nodes.infra.kuid.dev.id`: acts on a node and claims an ip address based on the prefx address families in the ipindex
- `nodes.infra.kuid.dev.itfce`: creates an abstract interface and subinterface resource per node. It is dependent on the `nodes.infra.kuid.dev.id` reconciler using the `IPClaimReady` condition/conditionType.
- `device.network.kubenet.dev.interfaces.srlinux.nokia.com`: is a JINJA2 reconciler that translates the interface to a vendor specific config if it is targeted for the provider: `srlinux.nokia.com`
- `device.network.kubenet.dev.subinterfaces.srlinux.nokia.com`: is a JINJA2 reconciler that translates the subinterface to a vendor specific config if it is targeted for the provider: `srlinux.nokia.com`

#### Reconiler config

Explore the reconciler logic in your IDE or ...

```shell
cat config/reconcilers/id/config.yaml 
cat config/reconcilers/itfce/config.yaml 
cat config/reconcilers/vendor/srlinux.nokia.com/config-interface/config.yaml 
cat config/reconcilers/vendor/srlinux.nokia.com/config-subinterface/config.yaml 
```

#### Reconiler business logic

Explore the reconciler logic in your IDE or ...

```shell
cat config/reconcilers/id/reconciler.star 
cat config/reconcilers/itfce/reconciler.star 
cat config/reconcilers/vendor/srlinux.nokia.com/config-interface/main.jinja2 
cat config/reconcilers/vendor/srlinux.nokia.com/config-interface/interface.jinja2 
cat config/reconcilers/vendor/srlinux.nokia.com/config-subinterface/main.jinja2 
cat config/reconcilers/vendor/srlinux.nokia.com/config-subinterface/subinterface.jinja2 
```

####  builtin functions

`is_ipv4` | `is_ipv6`: return true or false based on the prefix parameter

parameters:
  - prefix

`get_resource`: returns an empty resource with the apiVersion and Kind parameters specified

parameters:
  - apiVersion
  - kind


`client_get`: get a resource from the api server

parameters:
  - apiVersion
  - kind

## choreo server

If you have a previous server running, stop the server with ^C. You can reuse the window. Otherwise open a terminal window. 

Start the choreoserver with the -r and -s flags

-r flag enables builtin api for resource management (IPAM, AS, VLAN, GENID, EXTCOMM)
-s flag enables sdc schema validation and config generation

```bash
choreoctl server start config -r -s
```

The choreoserver support a version controlled backend (git) but we don't explore this in this exercise.

```json
{"time":"2024-09-30T19:26:06.771564+02:00","level":"INFO","message":"server started","logger":"choreoctl-logger","data":{"name":"choreoServer","address":"127.0.0.1:51000"}}
branchstore update main oldstate <nil> -> newstate CheckedOut
```

This creates 2 directories in the choreo project

- .choreo: used to download upstream references (not used in this example)
- db: storage backend for choreo (git storage) -> location of the CR(s)

## choreo client

Before we run choreo lets look at the input resources:

- ipindex: with an ipv4 block
- node: node1 in partition kubenet, region: region1, site: site1

Now lets run choreo once

```bash
choreoctl run once
```

You should see the reference being loaded in the .choreo directory
You should see the reconcilers being executed.

```bash
loading ...
opened repo https://github.com/kuidio/kuid.git ref cb752b9df3fe1ca9285a40e10d44dc87cd021162 ....
opened repo https://github.com/kubenet-dev/apis.git ref 71e5d139d272026db682be8a815d33a9f10d7b1f ....
opened repo https://github.com/sdcio/config-server.git ref aaf183a28ba8a3cff222321a767fc0022923af19 ....
loading done
running reconcilers ...
running root reconciler config
Run root summary
execution success, time(msec) 13.023ms
Reconciler                                                 Start Stop Requeue Error
interfaces.device.network.kubenet.dev.srlinux.nokia.com    4     4    0       0    
nodes.infra.kuid.dev.id                                    2     2    0       0    
nodes.infra.kuid.dev.itfce                                 2     2    0       0    
subinterfaces.device.network.kubenet.dev.srlinux.nokia.com 2     2    0       0    
running config validator ...
completed
```

What just happened?

a. the resources got loaded

- refs
- crds
- libraries
- input
- reconcilers

b. The reconciler registered using its reconciler config

c. The reconciler business logic got triggered by adding the input

d. the config validator ran

Let's see if it performed its job, by looking at the details

```bash
choreoctl run deps
```

You should see the children being created by the business logic

```bash
IPIndex.ipam.be.kuid.dev/v1alpha1 kubenet.default
+-IPClaim.ipam.be.kuid.dev/v1alpha1 kubenet.default.10.0.0.0-24
  +-IPEntry.ipam.be.kuid.dev/v1alpha1 default.kubenet.default.10.0.0.0-24
Node.infra.kuid.dev/v1alpha1 kubenet.region1.us-east.node1
+-Config.config.sdcio.dev/v1alpha1 kubenet.region1.us-east.node1
+-Interface.device.network.kubenet.dev/v1alpha1 kubenet.region1.us-east.node1.0.0.irb
  +-Config.config.sdcio.dev/v1alpha1 interface.kubenet.region1.us-east.node1.0.0.irb
+-Interface.device.network.kubenet.dev/v1alpha1 kubenet.region1.us-east.node1.0.0.system
  +-Config.config.sdcio.dev/v1alpha1 interface.kubenet.region1.us-east.node1.0.0.system
+-IPClaim.ipam.be.kuid.dev/v1alpha1 kubenet.region1.us-east.node1.ipv4
  +-IPEntry.ipam.be.kuid.dev/v1alpha1 default.kubenet.default.10.0.0.0-32
+-RunningConfig.config.sdcio.dev/v1alpha1 kubenet.region1.us-east.node1
+-RunningConfig.config.sdcio.dev/v1alpha1 kubenet.region1.us-east.node1.tree
+-SubInterface.device.network.kubenet.dev/v1alpha1 kubenet.region1.us-east.node1.0.0.0.system
  +-Config.config.sdcio.dev/v1alpha1 subinterface.kubenet.region1.us-east.node1.0.0.0.system
```

🎉 You created a config 🤘

Look at the config details and look at the ownerreferences and the fact that an ip address from the ipindex got referenced in the config.

```bash
choreoctl get configs.config.sdcio.dev subinterface.kubenet.region1.us-east.node1.0.0.0.system -o yaml
```

```yaml
apiVersion: config.sdcio.dev/v1alpha1
kind: Config
metadata:
  creationTimestamp: "2024-11-12T11:01:36Z"
  labels:
    config.sdcio.dev/targetName: kubenet.region1.us-east.node1
    config.sdcio.dev/targetNamespace: default
  name: subinterface.kubenet.region1.us-east.node1.0.0.0.system
  namespace: default
  ownerReferences:
  - apiVersion: device.network.kubenet.dev/v1alpha1
    controller: true
    kind: SubInterface
    name: kubenet.region1.us-east.node1.0.0.0.system
    uid: c8aebb0d-3726-40e5-8c82-ee48843566f9
  uid: 2d46564e-7776-4d47-b602-2f3f7b9f5a58
spec:
  config:
  - path: /
    value:
      interface:
      - name: system0
        subinterface:
        - admin-state: enable
          description: k8s-system.0
          index: 0
          ipv4:
            address:
            - ip-prefix: 10.0.0.0/32
            admin-state: enable
            unnumbered:
              admin-state: disable
  priority: 10
```

Running the diff indicates which resources got added

```bash
choreoctl run diff
```

```bash
+ config.sdcio.dev/v1alpha1, Kind=Config interface.kubenet.region1.us-east.node1.0.0.irb
+ config.sdcio.dev/v1alpha1, Kind=Config interface.kubenet.region1.us-east.node1.0.0.system
+ config.sdcio.dev/v1alpha1, Kind=Config kubenet.region1.us-east.node1
+ config.sdcio.dev/v1alpha1, Kind=Config subinterface.kubenet.region1.us-east.node1.0.0.0.system
+ config.sdcio.dev/v1alpha1, Kind=RunningConfig kubenet.region1.us-east.node1
+ config.sdcio.dev/v1alpha1, Kind=RunningConfig kubenet.region1.us-east.node1.tree
+ device.network.kubenet.dev/v1alpha1, Kind=Interface kubenet.region1.us-east.node1.0.0.irb
+ device.network.kubenet.dev/v1alpha1, Kind=Interface kubenet.region1.us-east.node1.0.0.system
+ device.network.kubenet.dev/v1alpha1, Kind=SubInterface kubenet.region1.us-east.node1.0.0.0.system
+ infra.kuid.dev/v1alpha1, Kind=Node kubenet.region1.us-east.node1
+ ipam.be.kuid.dev/v1alpha1, Kind=IPClaim kubenet.default.10.0.0.0-24
+ ipam.be.kuid.dev/v1alpha1, Kind=IPClaim kubenet.region1.us-east.node1.ipv4
+ ipam.be.kuid.dev/v1alpha1, Kind=IPEntry default.kubenet.default.10.0.0.0-24
+ ipam.be.kuid.dev/v1alpha1, Kind=IPEntry default.kubenet.default.10.0.0.0-32
+ ipam.be.kuid.dev/v1alpha1, Kind=IPIndex kubenet.default
```

Run the diff between running config and new config

```shell
chorecoctl run diff -c -a
```

```shell
~ config.sdcio.dev/v1alpha1, Kind=Config kubenet.region1.us-east.node1
  map[string]any{
+       "interface": []any{
+               map[string]any{
+                       "admin-state": string("enable"),
+                       "description": string("k8s-irb"),
+                       "name":        string("irb0"),
+               },
+               map[string]any{
+                       "admin-state":  string("enable"),
+                       "description":  string("k8s-system"),
+                       "name":         string("system0"),
+                       "subinterface": []any{map[string]any{...}},
+               },
+       },
        "network-instance": []any{map[string]any{"admin-state": string("enable"), "description": string("Management network instance"), "name": string("mgmt"), "protocols": map[string]any{"linux": map[string]any{"export-neighbors": bool(true), "export-routes": bool(true), "import-routes": bool(true)}}, ...}},
        "system":           map[string]any{"aaa": map[string]any{"authentication": map[string]any{"admin-user": map[string]any{"ssh-key": []any{string("ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQCPStMEn326bNzT2+RTGu8ywEhB"...), string("ssh-rsa AAAAB3NzaC1yc2EAAAABJQAAAgEAkulIK0tWXvHcg2kPG1h/4FD2+ia8"...), string("ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIC8E90POUf2RgNbUf1467iuIg42U"...)}}, "authentication-method": []any{string("local")}, "idle-timeout": float64(7200), "linuxadmin-user": map[string]any{"password": string("$y$j9T$uEpbQNxVBoRlKQbmY3usE/$VvTJySvfZcRx8vDJg2LmOxAdBF5IREyia7"...), "ssh-key": []any{string("ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQCPStMEn326bNzT2+RTGu8ywEhB"...), string("ssh-rsa AAAAB3NzaC1yc2EAAAABJQAAAgEAkulIK0tWXvHcg2kPG1h/4FD2+ia8"...), string("ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIC8E90POUf2RgNbUf1467iuIg42U"...)}}}, "server-group": []any{map[string]any{"name": string("local"), "type": string("local")}}}, "banner": map[string]any{"login-banner": string("................................................................"...)}, "dns": map[string]any{"network-instance": string("mgmt"), "server-list": []any{string("10.210.21.227"), string("10.210.21.228")}}, "grpc-server": []any{map[string]any{"admin-state": string("enable"), "name": string("insecure-mgmt"), "network-instance": string("mgmt"), "port": float64(57401), ...}, map[string]any{"admin-state": string("enable"), "name": string("mgmt"), "network-instance": string("mgmt"), "rate-limit": float64(65000), ...}}, ...},
  }
```

## Update ipindex with an ipv6 prefix

Lets add some nodes and links -> update the in file

```yaml
choreoctl apply -f - <<EOF
apiVersion: ipam.be.kuid.dev/v1alpha1
kind: IPIndex
metadata:
  name: kubenet.default
  namespace: default
spec:
  prefixes:
  - prefix: 10.0.0.0/24
    labels:
      infra.kuid.dev/purpose: loopback
  - prefix: 1000::/32
    labels:
      infra.kuid.dev/purpose: loopback
EOF
```

After updating the resource run the reconcilers again

```bash
choreoctl run once
```

Check the results.

```bash
choreoctl run diff
```

```bash
= config.sdcio.dev/v1alpha1, Kind=Config interface.kubenet.region1.us-east.node1.0.0.irb
= config.sdcio.dev/v1alpha1, Kind=Config interface.kubenet.region1.us-east.node1.0.0.system
~ config.sdcio.dev/v1alpha1, Kind=Config kubenet.region1.us-east.node1
~ config.sdcio.dev/v1alpha1, Kind=Config subinterface.kubenet.region1.us-east.node1.0.0.0.system
= config.sdcio.dev/v1alpha1, Kind=RunningConfig kubenet.region1.us-east.node1
= config.sdcio.dev/v1alpha1, Kind=RunningConfig kubenet.region1.us-east.node1.tree
= device.network.kubenet.dev/v1alpha1, Kind=Interface kubenet.region1.us-east.node1.0.0.irb
= device.network.kubenet.dev/v1alpha1, Kind=Interface kubenet.region1.us-east.node1.0.0.system
~ device.network.kubenet.dev/v1alpha1, Kind=SubInterface kubenet.region1.us-east.node1.0.0.0.system
~ infra.kuid.dev/v1alpha1, Kind=Node kubenet.region1.us-east.node1
= ipam.be.kuid.dev/v1alpha1, Kind=IPClaim kubenet.default.10.0.0.0-24
+ ipam.be.kuid.dev/v1alpha1, Kind=IPClaim kubenet.default.1000---32
= ipam.be.kuid.dev/v1alpha1, Kind=IPClaim kubenet.region1.us-east.node1.ipv4
+ ipam.be.kuid.dev/v1alpha1, Kind=IPClaim kubenet.region1.us-east.node1.ipv6
= ipam.be.kuid.dev/v1alpha1, Kind=IPEntry default.kubenet.default.10.0.0.0-24
= ipam.be.kuid.dev/v1alpha1, Kind=IPEntry default.kubenet.default.10.0.0.0-32
+ ipam.be.kuid.dev/v1alpha1, Kind=IPEntry default.kubenet.default.1000---128
+ ipam.be.kuid.dev/v1alpha1, Kind=IPEntry default.kubenet.default.1000---32
~ ipam.be.kuid.dev/v1alpha1, Kind=IPIndex kubenet.default
```

The dependency commands show the parent child relationships

```bash
choreoctl run deps
```

```bash
IPIndex.ipam.be.kuid.dev/v1alpha1 kubenet.default
+-IPClaim.ipam.be.kuid.dev/v1alpha1 kubenet.default.10.0.0.0-24
  +-IPEntry.ipam.be.kuid.dev/v1alpha1 default.kubenet.default.10.0.0.0-24
+-IPClaim.ipam.be.kuid.dev/v1alpha1 kubenet.default.1000---32
  +-IPEntry.ipam.be.kuid.dev/v1alpha1 default.kubenet.default.1000---32
Node.infra.kuid.dev/v1alpha1 kubenet.region1.us-east.node1
+-Config.config.sdcio.dev/v1alpha1 kubenet.region1.us-east.node1
+-Interface.device.network.kubenet.dev/v1alpha1 kubenet.region1.us-east.node1.0.0.irb
  +-Config.config.sdcio.dev/v1alpha1 interface.kubenet.region1.us-east.node1.0.0.irb
+-Interface.device.network.kubenet.dev/v1alpha1 kubenet.region1.us-east.node1.0.0.system
  +-Config.config.sdcio.dev/v1alpha1 interface.kubenet.region1.us-east.node1.0.0.system
+-IPClaim.ipam.be.kuid.dev/v1alpha1 kubenet.region1.us-east.node1.ipv4
  +-IPEntry.ipam.be.kuid.dev/v1alpha1 default.kubenet.default.10.0.0.0-32
+-IPClaim.ipam.be.kuid.dev/v1alpha1 kubenet.region1.us-east.node1.ipv6
  +-IPEntry.ipam.be.kuid.dev/v1alpha1 default.kubenet.default.1000---128
+-RunningConfig.config.sdcio.dev/v1alpha1 kubenet.region1.us-east.node1
+-RunningConfig.config.sdcio.dev/v1alpha1 kubenet.region1.us-east.node1.tree
+-SubInterface.device.network.kubenet.dev/v1alpha1 kubenet.region1.us-east.node1.0.0.0.system
  +-Config.config.sdcio.dev/v1alpha1 subinterface.kubenet.region1.us-east.node1.0.0.0.system
```

## Add a node

Lets add a node to the input

```yaml
choreoctl apply -f - <<EOF
apiVersion: infra.kuid.dev/v1alpha1
kind: Node
metadata:
  namespace: default
  name: kubenet.region1.us-east.node2
spec:
  platformType: ixrd3
  provider: srlinux.nokia.com
  version: 24.7.2
  partition: kubenet
  region: region1
  site: us-east
  node: node2
EOF
```

After updating the resource run the reconcilers again

```bash
choreoctl run once
```

Check if the node got a config and got an ip address assigned

```bash
choreoctl run diff
```

```bash
= config.sdcio.dev/v1alpha1, Kind=Config interface.kubenet.region1.us-east.node1.0.0.irb
= config.sdcio.dev/v1alpha1, Kind=Config interface.kubenet.region1.us-east.node1.0.0.system
+ config.sdcio.dev/v1alpha1, Kind=Config interface.kubenet.region1.us-east.node2.0.0.irb
+ config.sdcio.dev/v1alpha1, Kind=Config interface.kubenet.region1.us-east.node2.0.0.system
= config.sdcio.dev/v1alpha1, Kind=Config kubenet.region1.us-east.node1
+ config.sdcio.dev/v1alpha1, Kind=Config kubenet.region1.us-east.node2
= config.sdcio.dev/v1alpha1, Kind=Config subinterface.kubenet.region1.us-east.node1.0.0.0.system
+ config.sdcio.dev/v1alpha1, Kind=Config subinterface.kubenet.region1.us-east.node2.0.0.0.system
= config.sdcio.dev/v1alpha1, Kind=RunningConfig kubenet.region1.us-east.node1
= config.sdcio.dev/v1alpha1, Kind=RunningConfig kubenet.region1.us-east.node1.tree
+ config.sdcio.dev/v1alpha1, Kind=RunningConfig kubenet.region1.us-east.node2
+ config.sdcio.dev/v1alpha1, Kind=RunningConfig kubenet.region1.us-east.node2.tree
= device.network.kubenet.dev/v1alpha1, Kind=Interface kubenet.region1.us-east.node1.0.0.irb
= device.network.kubenet.dev/v1alpha1, Kind=Interface kubenet.region1.us-east.node1.0.0.system
+ device.network.kubenet.dev/v1alpha1, Kind=Interface kubenet.region1.us-east.node2.0.0.irb
+ device.network.kubenet.dev/v1alpha1, Kind=Interface kubenet.region1.us-east.node2.0.0.system
= device.network.kubenet.dev/v1alpha1, Kind=SubInterface kubenet.region1.us-east.node1.0.0.0.system
+ device.network.kubenet.dev/v1alpha1, Kind=SubInterface kubenet.region1.us-east.node2.0.0.0.system
= infra.kuid.dev/v1alpha1, Kind=Node kubenet.region1.us-east.node1
+ infra.kuid.dev/v1alpha1, Kind=Node kubenet.region1.us-east.node2
= ipam.be.kuid.dev/v1alpha1, Kind=IPClaim kubenet.default.10.0.0.0-24
= ipam.be.kuid.dev/v1alpha1, Kind=IPClaim kubenet.default.1000---32
= ipam.be.kuid.dev/v1alpha1, Kind=IPClaim kubenet.region1.us-east.node1.ipv4
= ipam.be.kuid.dev/v1alpha1, Kind=IPClaim kubenet.region1.us-east.node1.ipv6
+ ipam.be.kuid.dev/v1alpha1, Kind=IPClaim kubenet.region1.us-east.node2.ipv4
+ ipam.be.kuid.dev/v1alpha1, Kind=IPClaim kubenet.region1.us-east.node2.ipv6
= ipam.be.kuid.dev/v1alpha1, Kind=IPEntry default.kubenet.default.10.0.0.0-24
= ipam.be.kuid.dev/v1alpha1, Kind=IPEntry default.kubenet.default.10.0.0.0-32
+ ipam.be.kuid.dev/v1alpha1, Kind=IPEntry default.kubenet.default.10.0.0.1-32
= ipam.be.kuid.dev/v1alpha1, Kind=IPEntry default.kubenet.default.1000---128
= ipam.be.kuid.dev/v1alpha1, Kind=IPEntry default.kubenet.default.1000---32
+ ipam.be.kuid.dev/v1alpha1, Kind=IPEntry default.kubenet.default.1000--1-128
= ipam.be.kuid.dev/v1alpha1, Kind=IPIndex kubenet.default
```

When looking at the dependencies we see the proper hierarchy

```bash
choreoctl run deps
```

```bash
IPIndex.ipam.be.kuid.dev/v1alpha1 kubenet.default
+-IPClaim.ipam.be.kuid.dev/v1alpha1 kubenet.default.10.0.0.0-24
  +-IPEntry.ipam.be.kuid.dev/v1alpha1 default.kubenet.default.10.0.0.0-24
+-IPClaim.ipam.be.kuid.dev/v1alpha1 kubenet.default.1000---32
  +-IPEntry.ipam.be.kuid.dev/v1alpha1 default.kubenet.default.1000---32
Node.infra.kuid.dev/v1alpha1 kubenet.region1.us-east.node1
+-Config.config.sdcio.dev/v1alpha1 kubenet.region1.us-east.node1
+-Interface.device.network.kubenet.dev/v1alpha1 kubenet.region1.us-east.node1.0.0.irb
  +-Config.config.sdcio.dev/v1alpha1 interface.kubenet.region1.us-east.node1.0.0.irb
+-Interface.device.network.kubenet.dev/v1alpha1 kubenet.region1.us-east.node1.0.0.system
  +-Config.config.sdcio.dev/v1alpha1 interface.kubenet.region1.us-east.node1.0.0.system
+-IPClaim.ipam.be.kuid.dev/v1alpha1 kubenet.region1.us-east.node1.ipv4
  +-IPEntry.ipam.be.kuid.dev/v1alpha1 default.kubenet.default.10.0.0.0-32
+-IPClaim.ipam.be.kuid.dev/v1alpha1 kubenet.region1.us-east.node1.ipv6
  +-IPEntry.ipam.be.kuid.dev/v1alpha1 default.kubenet.default.1000---128
+-RunningConfig.config.sdcio.dev/v1alpha1 kubenet.region1.us-east.node1
+-RunningConfig.config.sdcio.dev/v1alpha1 kubenet.region1.us-east.node1.tree
+-SubInterface.device.network.kubenet.dev/v1alpha1 kubenet.region1.us-east.node1.0.0.0.system
  +-Config.config.sdcio.dev/v1alpha1 subinterface.kubenet.region1.us-east.node1.0.0.0.system
Node.infra.kuid.dev/v1alpha1 kubenet.region1.us-east.node2
+-Config.config.sdcio.dev/v1alpha1 kubenet.region1.us-east.node2
+-Interface.device.network.kubenet.dev/v1alpha1 kubenet.region1.us-east.node2.0.0.irb
  +-Config.config.sdcio.dev/v1alpha1 interface.kubenet.region1.us-east.node2.0.0.irb
+-Interface.device.network.kubenet.dev/v1alpha1 kubenet.region1.us-east.node2.0.0.system
  +-Config.config.sdcio.dev/v1alpha1 interface.kubenet.region1.us-east.node2.0.0.system
+-IPClaim.ipam.be.kuid.dev/v1alpha1 kubenet.region1.us-east.node2.ipv4
  +-IPEntry.ipam.be.kuid.dev/v1alpha1 default.kubenet.default.10.0.0.1-32
+-IPClaim.ipam.be.kuid.dev/v1alpha1 kubenet.region1.us-east.node2.ipv6
  +-IPEntry.ipam.be.kuid.dev/v1alpha1 default.kubenet.default.1000--1-128
+-RunningConfig.config.sdcio.dev/v1alpha1 kubenet.region1.us-east.node2
+-RunningConfig.config.sdcio.dev/v1alpha1 kubenet.region1.us-east.node2.tree
+-SubInterface.device.network.kubenet.dev/v1alpha1 kubenet.region1.us-east.node2.0.0.0.system
  +-Config.config.sdcio.dev/v1alpha1 subinterface.kubenet.region1.us-east.node2.0.0.0.system
```

!!! Note: 
Did you notice that your business logic does not need to deal with any history. Resources that were created and are no longer needed get automatcally removed. The same will happend for updates.

This leads to simpler and more maintainable automation.