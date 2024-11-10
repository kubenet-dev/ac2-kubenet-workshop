# Topology example

The goal of this exercise is to show you the basics of choreo (and kubernetes principles) through a topology exercise. We will show how to populate and inventory from an abstract topology definition

- introduces:
  - see hello-world for earlier concepts
new:
  - refs (segment your business logic in reusable code)
  - own reosurce
  - owner references
  - child resources
  - more builtin resource


## getting started

/// tab | Codespaces

run the environment in codespaces

```bash
https://codespaces.new/kubenet-dev/ac2-kubenet-workshop
```

///


/// tab | local environment

clone the choreo-examples git repo

```bash
git clone https://github.com/kubenet-dev/ac2-kubenet-workshop
```

///

Best to use 2 windows, one for the choreo server and one for the choreo client, since the choreo server will serve the system

## Explore the project

### crds

No local crds are referenced, but we have  2 references that import crds. This allows for reusable code. There is 2 types of references in choreo:
- crd based: only import crds -> we call this a crd child instance
- all: import everything (right now we only support 2 hierarchies of all refs) - root -> single root child, but 

### reconcilers

The directory where the reconcilers are located (`reconcilers`). Each reconciler is located in its own directory with a reconciler config and reconciler logic

#### Reconiler config

/// details | Reconciler Config

```yaml
--8<--
https://raw.githubusercontent.com/kubenet-dev/ac2-kubenet-workshop/main/part3/topology/reconcilers/topology/config.yaml
--8<--
```

///

Parameters:

- metadata.name: 
  - used for reconciler identification -> should be unique (use <resource>.<domain>.<unique id>)
  - used as finalizer
  - used for the fieldmanager in server side apply
  - used for debug and logging
  - changing this name once assigned could lead to issues when you have exisiting resources
- conditionType: used to report status of the resource. Should be unique per reconciler per resource
- specUpdate: allows the reconciler to update the spec
    - reconciler.star: starlark (python code) that def
- for: resource the reconciler is acting upon (mandatory)
  - selector: to filter events
- own: resources the reconciler can create/update/delete -> these resources will be assigned an ownerreference

#### Reconiler business logic

/// details | Reconciler

```yaml
--8<--
https://raw.githubusercontent.com/kubenet-dev/ac2-kubenet-workshop/main/part3/topology/reconcilers/topology/reconciler.star
--8<--
```

///

The reconciler updates the spec

####  builtin functions

reconciler_result: returns the result of the reconciler

parameters:
  - self: updated resource -> if specUpdate is not set only the status is used
  - requeue: true or false
  - requeue after: timeout
  - error: error message in case a failure occured
  - fatal: error message in case a failure occured and the business logic wants to interrupt (stop)

client_create: creates a child resource, but this call does not actually creates the resource but registers for create/update.

parameters:
  - resource -> subject to api/crd validation

## choreo server

start the choreoserver

```bash
choreoctl server start part3/topology
```

The choreoserver support a version controlled backend (git) but we don't explore this in this exercise.

```json
{"time":"2024-09-30T19:26:06.771564+02:00","level":"INFO","message":"server started","logger":"choreoctl-logger","data":{"name":"choreoServer","address":"127.0.0.1:51000"}}
branchstore update main oldstate <nil> -> newstate CheckedOut
```

This create 2 directories in the choreo project

- .choreo: used to download upstream references (not used in this example)
- db: storage backend for choreo (git storage) -> location of the CR(s)

## choreo client

Now run the reconciler

```bash
choreoctl run once
```

first you should see the reference being loaded in the .choreo directory
you should see the reconciler `topo.kubenet.dev.topologies.nodelink` being executed.

```bash
loading ...
opened repo https://github.com/kubenet-dev/apis.git ref 71e5d139d272026db682be8a815d33a9f10d7b1f ....
opened repo https://github.com/kuidio/kuid.git ref cb752b9df3fe1ca9285a40e10d44dc87cd021162 ....
loading done
running reconcilers ...
running root reconciler topology
Run root summary
execution success, time(msec) 10.391ms
Reconciler                           Start Stop Requeue Error
topo.kubenet.dev.topologies.nodelink 3     3    0       0    
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


let's see if it performed its job, by looking at the details of the HelloWorld manifest

```bash
choreoctl run deps
```

You should see the children being created by the business logic

```bash
Topology.topo.kubenet.dev/v1alpha1 kubenet
+-Link.infra.kuid.dev/v1alpha1 kubenet.region1.us-east.node1.1.0.1.0.node2.1.0.1.0
+-Node.infra.kuid.dev/v1alpha1 kubenet.region1.us-east.node1
+-Node.infra.kuid.dev/v1alpha1 kubenet.region1.us-east.node2
```

🎉 You populated the inventory. 🤘

look at the node details and look at the ownerreferences

```bash
choreoctl get nodes.infra.kuid.dev -o yaml
```

```yaml
apiVersion: infra.kuid.dev/v1alpha1
items:
- apiVersion: infra.kuid.dev/v1alpha1
  kind: Node
  metadata:
    creationTimestamp: "2024-11-10T17:37:52Z"
    name: kubenet.region1.us-east.node1
    namespace: default
    ownerReferences:
    - apiVersion: topo.kubenet.dev/v1alpha1
      controller: true
      kind: Topology
      name: kubenet
      uid: 7f944880-5a4d-43ed-b956-42ec9e91783a
    uid: e64e01ff-db13-4b9f-94f6-3dccec52be79
  spec:
    node: node1
    partition: kubenet
    platformType: ixrd3
    provider: srlinux.nokia.com
    region: region1
    site: us-east
    version: 24.7.2
- apiVersion: infra.kuid.dev/v1alpha1
  kind: Node
  metadata:
    creationTimestamp: "2024-11-10T17:37:52Z"
    name: kubenet.region1.us-east.node2
    namespace: default
    ownerReferences:
    - apiVersion: topo.kubenet.dev/v1alpha1
      controller: true
      kind: Topology
      name: kubenet
      uid: 7f944880-5a4d-43ed-b956-42ec9e91783a
    uid: 6cd91c94-8835-45eb-aedd-c40c777738b9
  spec:
    node: node2
    partition: kubenet
    platformType: ixrd3
    provider: srlinux.nokia.com
    region: region1
    site: us-east
    version: 24.7.2
kind: NodeList
```

you can do the same for links

```bash
choreoctl get nodes.infra.kuid.dev -o yaml
```

```yaml
apiVersion: infra.kuid.dev/v1alpha1
items:
- apiVersion: infra.kuid.dev/v1alpha1
  kind: Link
  metadata:
    creationTimestamp: "2024-11-10T17:37:52Z"
    name: kubenet.region1.us-east.node1.1.0.1.0.node2.1.0.1.0
    namespace: default
    ownerReferences:
    - apiVersion: topo.kubenet.dev/v1alpha1
      controller: true
      kind: Topology
      name: kubenet
      uid: 7f944880-5a4d-43ed-b956-42ec9e91783a
    uid: 6ad72697-3fed-448a-b677-5a4e76f2e198
  spec:
    endpoints:
    - adaptor: sfp
      endpoint: 1
      node: node1
      partition: kubenet
      port: 1
      region: region1
      site: us-east
    - adaptor: sfp
      endpoint: 1
      node: node2
      partition: kubenet
      port: 1
      region: region1
      site: us-east
    internal: true
kind: LinkList
```

the run diff command allows you to see the resource that got added

```bash
choreoctl run diff
```

```bash
+ infra.kuid.dev/v1alpha1, Kind=Link kubenet.region1.us-east.node1.1.0.1.0.node2.1.0.1.0
+ infra.kuid.dev/v1alpha1, Kind=Node kubenet.region1.us-east.node1
+ infra.kuid.dev/v1alpha1, Kind=Node kubenet.region1.us-east.node2
```

## Update the topology - add links/nodes

Lets add some nodes and links -> update the in file

```yaml
apiVersion: topo.kubenet.dev/v1alpha1
kind: Topology
metadata:
  name: kubenet
  namespace: default
spec:
  defaults:
    provider: srlinux.nokia.com
    platformType: ixrd3
    version: 24.7.2
    region: region1
    site: us-east
  nodes:
  - name: node1
  - name: node2
  - name: node3
  - name: node4
  links:
  - endpoints:
    - {node: node1, port: 1, endpoint: 1, adaptor: "sfp"}
    - {node: node2, port: 1, endpoint: 1, adaptor: "sfp"}
  - endpoints:
    - {node: node2, port: 2, endpoint: 1, adaptor: "sfp"}
    - {node: node3, port: 2, endpoint: 1, adaptor: "sfp"}
  - endpoints:
    - {node: node3, port: 1, endpoint: 1, adaptor: "sfp"}
    - {node: node4, port: 1, endpoint: 1, adaptor: "sfp"}
  - endpoints:
    - {node: node4, port: 2, endpoint: 1, adaptor: "sfp"}
    - {node: node1, port: 2, endpoint: 1, adaptor: "sfp"}
```

After updating the resource run the reconcilers again

```bash
choreoctl run once
```

check the results

```bash
choreoctl run diff
```

```bash
= infra.kuid.dev/v1alpha1, Kind=Link kubenet.region1.us-east.node1.1.0.1.0.node2.1.0.1.0
+ infra.kuid.dev/v1alpha1, Kind=Link kubenet.region1.us-east.node2.2.0.1.0.node3.2.0.1.0
+ infra.kuid.dev/v1alpha1, Kind=Link kubenet.region1.us-east.node3.1.0.1.0.node4.1.0.1.0
+ infra.kuid.dev/v1alpha1, Kind=Link kubenet.region1.us-east.node4.2.0.1.0.node1.2.0.1.0
= infra.kuid.dev/v1alpha1, Kind=Node kubenet.region1.us-east.node1
= infra.kuid.dev/v1alpha1, Kind=Node kubenet.region1.us-east.node2
+ infra.kuid.dev/v1alpha1, Kind=Node kubenet.region1.us-east.node3
+ infra.kuid.dev/v1alpha1, Kind=Node kubenet.region1.us-east.node4
~ topo.kubenet.dev/v1alpha1, Kind=Topology kubenet
```

The dependency commands show the parent child dependencies

```bash
choreoctl run deps
```

```bash
Topology.topo.kubenet.dev/v1alpha1 kubenet
+-Link.infra.kuid.dev/v1alpha1 kubenet.region1.us-east.node1.1.0.1.0.node2.1.0.1.0
+-Link.infra.kuid.dev/v1alpha1 kubenet.region1.us-east.node2.2.0.1.0.node3.2.0.1.0
+-Link.infra.kuid.dev/v1alpha1 kubenet.region1.us-east.node3.1.0.1.0.node4.1.0.1.0
+-Link.infra.kuid.dev/v1alpha1 kubenet.region1.us-east.node4.2.0.1.0.node1.2.0.1.0
+-Node.infra.kuid.dev/v1alpha1 kubenet.region1.us-east.node1
+-Node.infra.kuid.dev/v1alpha1 kubenet.region1.us-east.node2
+-Node.infra.kuid.dev/v1alpha1 kubenet.region1.us-east.node3
+-Node.infra.kuid.dev/v1alpha1 kubenet.region1.us-east.node4
```

## Update the topology - delete links/nodes

Lets delete node1 and its respective links and run the reconcilers again

```yaml
apiVersion: topo.kubenet.dev/v1alpha1
kind: Topology
metadata:
  name: kubenet
  namespace: default
spec:
  defaults:
    provider: srlinux.nokia.com
    platformType: ixrd3
    version: 24.7.2
    region: region1
    site: us-east
  nodes:
  - name: node2
  - name: node3
  - name: node4
  links:
  - endpoints:
    - {node: node2, port: 2, endpoint: 1, adaptor: "sfp"}
    - {node: node3, port: 2, endpoint: 1, adaptor: "sfp"}
  - endpoints:
    - {node: node3, port: 1, endpoint: 1, adaptor: "sfp"}
    - {node: node4, port: 1, endpoint: 1, adaptor: "sfp"}
```

After updating the resource run the reconcilers again

```bash
choreoctl run once
```

When looking at the diff we see that the following links and node got deleted
- `infra.kuid.dev/v1alpha1, Kind=Link kubenet.region1.us-east.node1.1.0.1.0.node2.1.0.1.0`
- `infra.kuid.dev/v1alpha1, Kind=Link kubenet.region1.us-east.node4.2.0.1.0.node1.2.0.1.0`
- `infra.kuid.dev/v1alpha1, Kind=Node kubenet.region1.us-east.node1`

and the  topology got updated

```bash
choreoctl run diff
```

```bash
- infra.kuid.dev/v1alpha1, Kind=Link kubenet.region1.us-east.node1.1.0.1.0.node2.1.0.1.0
= infra.kuid.dev/v1alpha1, Kind=Link kubenet.region1.us-east.node2.2.0.1.0.node3.2.0.1.0
= infra.kuid.dev/v1alpha1, Kind=Link kubenet.region1.us-east.node3.1.0.1.0.node4.1.0.1.0
- infra.kuid.dev/v1alpha1, Kind=Link kubenet.region1.us-east.node4.2.0.1.0.node1.2.0.1.0
- infra.kuid.dev/v1alpha1, Kind=Node kubenet.region1.us-east.node1
= infra.kuid.dev/v1alpha1, Kind=Node kubenet.region1.us-east.node2
= infra.kuid.dev/v1alpha1, Kind=Node kubenet.region1.us-east.node3
= infra.kuid.dev/v1alpha1, Kind=Node kubenet.region1.us-east.node4
~ topo.kubenet.dev/v1alpha1, Kind=Topology kubenet
```

When looking at the dependencies we see the proper hierarchy

```bash
choreoctl run deps
```

```bash
Topology.topo.kubenet.dev/v1alpha1 kubenet
+-Link.infra.kuid.dev/v1alpha1 kubenet.region1.us-east.node2.2.0.1.0.node3.2.0.1.0
+-Link.infra.kuid.dev/v1alpha1 kubenet.region1.us-east.node3.1.0.1.0.node4.1.0.1.0
+-Node.infra.kuid.dev/v1alpha1 kubenet.region1.us-east.node2
+-Node.infra.kuid.dev/v1alpha1 kubenet.region1.us-east.node3
+-Node.infra.kuid.dev/v1alpha1 kubenet.region1.us-east.node4
```

!!! Note: 
Did you notice that your business logic does not need to deal with any history. Resources that were created and are no longer needed get automatcally removed. The same will happend for updates.

This leads to simpler and more maintainable automation.