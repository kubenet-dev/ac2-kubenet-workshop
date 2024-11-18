### Lab Guide: Experience Kubernetes Basic Elements Using `kubectl` and cert-manager

This lab will help students experience basic Kubernetes elements such as nodes, pods, deployments, and labels by using the `cert-manager` app. We will explain how each of these elements works using real commands and an example.

---

### **Step 1: Set Up Your Environment**
1. **Verify your access to the cluster**  
   Check if `kubectl` is correctly set up by listing the nodes in your cluster:
   ```bash
   kubectl get nodes
   ```
   You should see your single node listed, indicating that your Kubernetes environment is ready.

---

### **Step 2: Deploy the cert-manager Application**
1. **Deploy cert-manager**  
   This command will install `cert-manager`, a Kubernetes component that helps manage SSL/TLS certificates:
   ```bash
   kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.13.3/cert-manager.yaml
   ```

2. **Wait for the Webhook to be Available**  
   Before applying more resources, wait for the `cert-manager-webhook` deployment to be ready:
   ```bash
   kubectl wait -n cert-manager --for=condition=Available=True --timeout=300s deployments.apps cert-manager-webhook
   ```

**Explanation:**  
- **What the app does**: `cert-manager` automates the management and issuance of TLS certificates in Kubernetes, often used for securing services running in your cluster.
- **Why wait for the webhook**: The webhook component validates changes made to the cert-manager resources, so it must be running before applying any further configurations.

---

### **Step 3: Explore Nodes, Pods, and Deployments**

1. **Check the cert-manager Pods**  
   Pods are the smallest deployable units in Kubernetes, and `cert-manager` creates several of them:
   ```bash
   kubectl get pods -n cert-manager
   ```

   **Explanation**:  
   - A **pod** represents one or more containers running together on a node.
   - Here, each cert-manager component is running in its own pod.

2. **View the Deployments**  
   Deployments ensure that the right number of pods are running, even if some fail:
   ```bash
   kubectl get deployments -n cert-manager
   ```

   **Explanation**:  
   - A **deployment** manages multiple replicas of a pod and ensures high availability.
   - The cert-manager deployment handles how the `cert-manager` pods are created, updated, and scaled.

---

### **Step 4: Understand Labels and Filtering Resources**
1. **View Pod Labels**  
   Labels are key-value pairs that help organize and select Kubernetes resources. Let's view the labels for one of the cert-manager pods:
   ```bash
   kubectl get pods -n cert-manager --show-labels
   ```

2. **Filter Pods Using Labels**  
   You can filter pods based on their labels. For example, to see only pods related to the cert-manager-controller:
   ```bash
   kubectl get pods -n cert-manager -l app=cert-manager
   ```

   **Explanation**:  
   - **Labels** are used to group and filter resources. They can help when managing large applications by identifying specific components.
   - Here, the label `app=cert-manager` is used to filter and list only the cert-manager pods.

---

### **Step 5: Inspect Resource Details**
1. **Describe a Pod**  
   Use `kubectl describe` to get detailed information about a pod, including events, resource usage, and node placement:
   ```bash
   kubectl describe pod <pod-name> -n cert-manager
   ```

   **Explanation**:  
   - This command shows detailed information about a specific resource, including which node it's running on, the containers it holds, and events related to its lifecycle.


### **Conclusion:**
In this lab, students learned how to interact with Kubernetes' basic components using the `cert-manager` app as an example. They explored:
- Nodes: The machines running the workloads.
- Pods: The basic units of deployment in Kubernetes.
- Deployments: Ensuring high availability and scaling.
- Labels: Organizing and filtering resources.
- API Registration: Checking if API has been registered.

By understanding and applying these core concepts, students can effectively manage and troubleshoot applications running in a Kubernetes cluster.
