# HelloWorld example

The goal of this exercise is to show you the basics of choreo (and kubernetes principles). We also show how you can customize the business logic using a hello world example. The Hello World API is already generated from this [source][#Hello world resource (API)]

- introduce:
  - resources (crds)
  - for resource
  - reconcilers
  - reconciler configs
  - reconciler builtin functions
  - conditions/conditionType
  - finalizer

## Getting started

move you PWD to the `ac2-kubenet-workshop/Part 3` subdirectory

## Explore the project

### CRDs

The directory where the crds are located (`crds`)

```shell
cat hello-world/crds/example.com_helloworlds.yaml
```

[crd](https://raw.githubusercontent.com/kubenet-dev/ac2-kubenet-workshop/refs/heads/main/Part%203/hello-world/crds/example.com_helloworlds.yaml)

### Input

The input directory where your input manifest are located

```shell
cat hello-world/in/example.com.helloworlds.test.yaml 
```

[input](https://raw.githubusercontent.com/kubenet-dev/ac2-kubenet-workshop/refs/heads/main/Part%203/hello-world/in/example.com.helloworlds.test.yaml)

### Reconcilers

The directory where the reconcilers are located (`reconcilers`). Each reconciler is located in its own directory with a reconciler config and reconciler logic

#### Reconiler config

```shell
cat hello-world/reconcilers/hello-world/config.yaml 
```

[reconciler config](https://raw.githubusercontent.com/kubenet-dev/ac2-kubenet-workshop/refs/heads/main/Part%203/hello-world/reconcilers/hello-world/config.yaml)

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


#### Reconiler business logic

```shell
cat hello-world/reconcilers/hello-world/reconciler.star
```

[reconciler business logic](https://raw.githubusercontent.com/kubenet-dev/ac2-kubenet-workshop/refs/heads/main/Part%203/hello-world/reconcilers/hello-world/reconciler.star)

The business logic is simple, it updates the spec with new data.

####  builtin functions

`reconciler_result`: returns the result of the reconciler

parameters:
  - self: updated resource -> if specUpdate is not set only the status is used
  - requeue: true or false
  - requeue after: timeout
  - error: error message in case a failure occured
  - fatal: error message in case a failure occured and the business logic wants to interrupt (stop)

## choreo server

open a terminal window and start the choreoserver 

```shell
choreoctl server start hello-world
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

Open a 2nd terminal where you intercat with the server using choreoctl

```shell
choreoctl run once
```

you should see the reconciler `helloworlds.example.com.hello-world` being executed.

```shell
loading ...
running reconcilers ...
running root reconciler hello-world
Run root summary
execution success, time(msec) 2.172ms
Reconciler                          Start Stop Requeue Error
helloworlds.example.com.hello-world 2     2    0       0    
completed
```

What just happened?

a. the resources got loaded

- crds
- input
- reconcilers

b. The reconciler registered using its reconciler config

c. The reconciler business logic got triggered by adding the input

let's see if it performed its job, by looking at the details of the HelloWorld manifest

```shell
choreoctl get helloworlds.example.com test -o yaml
```

We should see spec.greeting being changed to `hello choreo`

```yaml
apiVersion: example.com/v1alpha1
kind: HelloWorld
metadata:
  annotations:
    api.choreo.kform.dev/origin: '{"kind":"File"}'
  creationTimestamp: "2024-11-10T15:57:29Z"
  finalizers:
  - helloworlds.example.com.hello-world
  name: test
  namespace: default
  uid: d8211ad3-9967-4fac-814e-d3f5f85f382c
spec:
  greeting: hello choreo
status:
  conditions:
  - lastTransitionTime: "2024-11-10T15:57:29Z"
    message: ""
    reason: Ready
    status: "True"
    type: Ready
```

🎉 You ran you first choreo reconciler. 🤘

Did you notice none of this required a kubernetes cluster?
Choreo applies the kubernetes principles w/o imposing all the kubernetes container orchestration primitives.

Try changing the business logic from `Hello choreo` to `hello <your name>` and execute the business logic again

```python
def reconcile(self):
  self['spec'] = {"greeting": "hello me"}
  return reconcile_result(self, False, 0, "", False)
```

This should result in the following outcome if we run the business logic again.

```shell
choreoctl run once
```

```yaml
apiVersion: example.com/v1alpha1
kind: HelloWorld
metadata:
  annotations:
    api.choreo.kform.dev/origin: '{"kind":"File"}'
  creationTimestamp: "2024-09-30T17:49:34Z"
  generation: 1
  name: test
  namespace: default
  resourceVersion: "1"
  uid: deedbf64-b348-477e-9fbb-d2738ab4f3b0
spec:
  greeting: hello me
status:
  conditions:
  - lastTransitionTime: "2024-09-30T17:49:34Z"
    message: ""
    reason: Ready
    status: "True"
    type: Ready
```

You can also introduce an error and see what happens; e.g. change `greeting` to `greetings` which is an invalid json key in the schema.

```python
def reconcile(self):
  self['spec'] = {"greetings": "hello me"}
  return reconcile_result(self, False, 0, "", False)
```

when executing

```shell
choreoctl run once
```

the following result is obtained, indicating the schema error

```shell
execution failed
  reason task helloworlds.example.com.hello-world.HelloWorld.example.com.test message cannot apply resource, err: rpc error: code = InvalidArgument desc = fieldmanager apply failed err: failed to create typed patch object (default/test; example.com/v1alpha1, Kind=HelloWorld): .spec.greetings: field not declared in schema
completed
```

## Hello world resource source (API)

```golang
// HelloWorldSpec defines the desired state of the HelloWorld
type HelloWorldSpec struct {
	Greeting string `json:"greeting,omitempty" protobuf:"bytes,1,opt,name=greeting"`
}

// HelloWorldStatus defines the state of the HelloWorld resource
type HelloWorldStatus struct {
	// ConditionedStatus provides the status of the resource using conditions
	// - a ready condition indicates the overall status of the resource
	ConditionedStatus `json:",inline" yaml:",inline" protobuf:"bytes,1,opt,name=conditionedStatus"`
}

// +kubebuilder:object:root=true
// HelloWorld defines the HelloWorld API
type HelloWorld struct {
	metav1.TypeMeta   `json:",inline"`
	metav1.ObjectMeta `json:"metadata,omitempty" protobuf:"bytes,1,opt,name=metadata"`

	Spec HelloWorldSpec `json:"spec,omitempty" protobuf:"bytes,2,opt,name=spec"`
	Status HelloWorldStatus `json:"status,omitempty" protobuf:"bytes,3,opt,name=status"`
}
```