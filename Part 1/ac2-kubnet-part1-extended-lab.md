Here's the complete document with the required patches to add the context for code installation and reconciliation logging. The YAML content remains the same as per your request.

---

### Lab Guide: Create and Reconcile a Custom Resource Definition (CRD)

**Note: This lab is an extension of the Session 1 and will not be covered as part of the workshop**

This simplified lab guide will help you create a Custom Resource Definition (CRD), deploy a custom resource, and build a basic controller to reconcile the state of the custom resource.

---

### **Step 1: Set Up Your Environment**
Before starting, make sure your Kubernetes cluster is running and you have access to `kubectl`.

1. **Create a new namespace for the lab**  
   Create a namespace to keep everything organized:
   ```bash
   kubectl create namespace krm-crd-lab
   ```

---

### **Step 2: Create a Custom Resource Definition (CRD)**
We will define a new CRD called `CronTab` to manage scheduling configurations.

1. **Create a YAML file for the CRD**  
   Create a file named `crontab-crd.yaml` with the following content:
   ```yaml
   apiVersion: apiextensions.k8s.io/v1
   kind: CustomResourceDefinition
   metadata:
     name: crontabs.stable.example.com
   spec:
     group: stable.example.com
     names:
       kind: CronTab
       plural: crontabs
       singular: crontab
     scope: Namespaced
     versions:
       - name: v1
         served: true
         storage: true
         schema:
           openAPIV3Schema:
             type: object
             properties:
               spec:
                 type: object
                 properties:
                   cronSpec:
                     type: string
                   image:
                     type: string
                   replicas:
                     type: integer
   ```

2. **Apply the CRD to the cluster**
   ```bash
   kubectl apply -f crontab-crd.yaml
   ```

3. **Verify the CRD is created**
   ```bash
   kubectl get crd
   ```

---

### **Step 3: Create a Custom Resource (CR)**
Now that the CRD is defined, we can create a custom resource that uses it.

1. **Create a YAML file for the CronTab resource**  
   Create a file named `my-crontab.yaml` with the following content:
   ```yaml
   apiVersion: stable.example.com/v1
   kind: CronTab
   metadata:
     name: my-crontab
     namespace: krm-crd-lab
   spec:
     cronSpec: "* * * * */5"
     image: "busybox"
     replicas: 2
   ```

2. **Apply the custom resource to the cluster**
   ```bash
   kubectl apply -f my-crontab.yaml
   ```

3. **Verify the resource is created**
   ```bash
   kubectl get crontabs -n krm-crd-lab
   ```

---

### **Step 3.1: Configure Permissions**
To allow the controller to access the `CronTab` resource, you need to create a Role and RoleBinding:

1. **Create the Role**  
   Save the following YAML as `crontab-controller-role.yaml`:

   ```yaml
   apiVersion: rbac.authorization.k8s.io/v1
   kind: Role
   metadata:
     namespace: krm-crd-lab
     name: crontab-controller-role
   rules:
     - apiGroups: ["stable.example.com"]
       resources: ["crontabs"]
       verbs: ["get", "list", "watch"]
   ```

2. **Create the RoleBinding**  
   Save the following YAML as `crontab-controller-rolebinding.yaml`:

   ```yaml
   apiVersion: rbac.authorization.k8s.io/v1
   kind: RoleBinding
   metadata:
     name: crontab-controller-rolebinding
     namespace: krm-crd-lab
   subjects:
     - kind: ServiceAccount
       name: default
       namespace: krm-crd-lab
   roleRef:
     kind: Role
     name: crontab-controller-role
     apiGroup: rbac.authorization.k8s.io
   ```

3. **Apply the Role and RoleBinding**
   ```bash
   kubectl apply -f crontab-controller-role.yaml
   kubectl apply -f crontab-controller-rolebinding.yaml
   ```

---

### **Step 4: Create a Basic Controller to Reconcile the Custom Resource**
We’ll create a simple controller that watches the `CronTab` resource and prints messages when it detects changes.

1. **Create a YAML file for the controller**  
   Create a file named `crontab-controller.yaml` with the following content:

   ```yaml
   apiVersion: v1
   kind: ConfigMap
   metadata:
     name: crontab-controller
     namespace: krm-crd-lab
   data:
     controller.py: |
       import os
       import time
       import sys
       from deepdiff import DeepDiff
       import kubernetes
       from kubernetes import client, config
   
       config.load_incluster_config()
       api_instance = client.CustomObjectsApi()
   
       # Dictionary to store the last known state of each CronTab
       last_observed_state = {}
   
       while True:
           crontabs = api_instance.list_namespaced_custom_object(
               group="stable.example.com", version="v1", namespace="krm-crd-lab", plural="crontabs"
           )
           for crontab in crontabs['items']:
               name = crontab['metadata']['name']
               current_state = crontab['spec']
   
               # Check for changes by comparing with the last known state
               if name in last_observed_state:
                   # Detect changes between the current state and the last observed state
                   diff = DeepDiff(last_observed_state[name], current_state, ignore_order=True)
                   if diff:
                       print(f"Changes detected in CronTab '{name}': {diff}", flush=True)
                   else:
                       print(f"No changes detected for CronTab '{name}'", flush=True)
               else:
                   print(f"First observation of CronTab '{name}': {current_state}", flush=True)
   
               # Update the last observed state
               last_observed_state[name] = current_state
   
           time.sleep(30)

   ```

2. **Apply the controller configuration**
   ```bash
   kubectl apply -f crontab-controller.yaml
   ```

3. **Run the controller in a pod (temporary setup)**  
   This command will run the controller inside a Python container with the necessary packages installed:

   ```yaml
   apiVersion: v1
   kind: Pod
   metadata:
     name: crontab-controller
     namespace: krm-crd-lab
   spec:
     initContainers:
       - name: install-kubernetes-client
         image: python:3.9
         command:
           - /bin/sh
           - -c
           - |
             pip install --target /app kubernetes deepdiff
         volumeMounts:
           - name: app-volume
             mountPath: /app
     containers:
       - name: crontab-controller
         image: python:3.9
         command: ["python", "/app/controller.py"]
         volumeMounts:
           - name: app-volume
             mountPath: /app
           - name: config-volume
             mountPath: /app/controller.py
             subPath: controller.py
         env:
           - name: PYTHONPATH
             value: "/app"
     volumes:
       - name: app-volume
         emptyDir: {}
       - name: config-volume
         configMap:
           name: crontab-controller
   ```

4. **Start the Pod**

   ```bash
   kubectl apply -f crontab-controller-pod.yaml
   ```

5. **Check the controller logs to see reconciliation**  
   The controller will print messages as it reconciles the `CronTab` resources:

   ```bash
   kubectl logs crontab-controller -n krm-crd-lab
   ```

---

### **Step 5: Modify the Custom Resource**
Let’s change the number of replicas in the `CronTab` resource to see how the controller reacts.

1. **Update the `my-crontab.yaml` to change replicas**
   ```yaml
   replicas: 3
   ```

2. **Reapply the custom resource**
   ```bash
   kubectl apply -f my-crontab.yaml
   ```

3. **Check the logs again to observe reconciliation**
   ```bash
   kubectl logs crontab-controller -n krm-crd-lab
   ```

---

### **Step 6: Clean Up**
Once you're done with the lab, clean up the resources:

1. **Delete the custom resource**
   ```bash
   kubectl delete -f my-crontab.yaml
   ```

2. **Delete the CRD**
   ```bash
   kubectl delete -f crontab-crd.yaml
   ```

3. **Delete the namespace**
   ```bash
   kubectl delete namespace krm-crd-lab
   ```

---

### **Conclusion:**
In this lab, you learned how to create and manage a custom resource in Kubernetes using CRDs, and you built a basic controller to reconcile the state of the custom resource. This experience helps illustrate how Kubernetes can be extended beyond its built-in resources using CRDs.
