# Kubernetes Cluster Administration: Essential Commands

A practical command reference for Kubernetes administrators working with Minikube, AKS, and self-managed Kubernetes clusters.

> **Important:** Some commands depend on the Kubernetes distribution and your permissions. Direct etcd administration is generally available only on self-managed clusters. In AKS, Azure manages the control plane and etcd.

---

## 1. Cluster Information

```bash
# Display cluster control-plane information
kubectl cluster-info

# Display detailed cluster information (can produce a large output)
kubectl cluster-info dump

# Display Kubernetes client and server versions
kubectl version

# List nodes with detailed information
kubectl get nodes -o wide

# List namespaces
kubectl get namespaces

# Check API server readiness and liveness
kubectl get --raw /readyz
kubectl get --raw /livez
kubectl get --raw '/readyz?verbose'
kubectl get --raw '/livez?verbose'

# View recent cluster events
kubectl get events -A --sort-by=.metadata.creationTimestamp
```

> `kubectl get componentstatuses` is deprecated or unavailable in modern Kubernetes versions. Use node status, system Pods, and API health endpoints instead.

---

## 2. Context and Kubeconfig Management

A **context** specifies the cluster, user, and default namespace that `kubectl` uses.

```bash
# Show the current context
kubectl config current-context

# List all contexts
kubectl config get-contexts

# Switch to a context
kubectl config use-context <CONTEXT_NAME>

# Display kubeconfig settings
kubectl config view

# Display kubeconfig including credentials (sensitive)
kubectl config view --raw

# Set the default namespace for the current context
kubectl config set-context --current --namespace=default

# Rename a context
kubectl config rename-context <OLD_NAME> <NEW_NAME>

# Delete a context entry
kubectl config delete-context <CONTEXT_NAME>

# Display the current kubeconfig file path
kubectl config view --minify
```

**Security:** `kubectl config view --raw` may expose credentials. Never share its output publicly.

---

## 3. Node Administration

```bash
# List nodes
kubectl get nodes

# Show detailed node information
kubectl describe node <NODE_NAME>

# Display node labels
kubectl get nodes --show-labels

# Add or update a node label
kubectl label node <NODE_NAME> environment=production

# Remove a node label
kubectl label node <NODE_NAME> environment-

# Mark a node as unschedulable
kubectl cordon <NODE_NAME>

# Evict eligible workloads and prepare a node for maintenance
kubectl drain <NODE_NAME> --ignore-daemonsets

# Allow Pods to be scheduled on the node again
kubectl uncordon <NODE_NAME>
```

> **Caution:** `kubectl drain` can disrupt workloads. Review PodDisruptionBudgets, local storage, DaemonSets, and workload availability before using it.

---

## 4. Namespace Administration

```bash
# List namespaces
kubectl get namespaces

# Create a namespace
kubectl create namespace dev

# Describe a namespace
kubectl describe namespace dev

# List common resources in a namespace
kubectl get all -n dev

# List Pods in all namespaces
kubectl get pods -A

# Delete a namespace (destructive)
kubectl delete namespace dev
```

---

## 5. Pod Administration

```bash
# List Pods in the current namespace
kubectl get pods

# List Pods in all namespaces
kubectl get pods -A

# Display Pod IP and node placement
kubectl get pods -o wide

# Describe a Pod
kubectl describe pod <POD_NAME>

# View container logs
kubectl logs <POD_NAME>

# Follow logs continuously
kubectl logs -f <POD_NAME>

# View logs from the previous container instance
kubectl logs <POD_NAME> --previous

# View the last 100 log lines
kubectl logs <POD_NAME> --tail=100

# Execute a shell inside a container
kubectl exec -it <POD_NAME> -- /bin/sh

# Delete a Pod (a controller may recreate it)
kubectl delete pod <POD_NAME>
```

For a Pod in another namespace, add `-n <NAMESPACE>`.

---

## 6. Deployment and ReplicaSet Management

```bash
# List deployments
kubectl get deployments

# Describe a deployment
kubectl describe deployment <DEPLOYMENT_NAME>

# Scale a deployment
kubectl scale deployment <DEPLOYMENT_NAME> --replicas=3

# Check rollout progress
kubectl rollout status deployment/<DEPLOYMENT_NAME>

# View rollout history
kubectl rollout history deployment/<DEPLOYMENT_NAME>

# Roll back to the previous revision
kubectl rollout undo deployment/<DEPLOYMENT_NAME>

# Restart a deployment
kubectl rollout restart deployment/<DEPLOYMENT_NAME>

# List ReplicaSets
kubectl get replicasets
```

---

## 7. Services and Networking

```bash
# List Services
kubectl get services

# Describe a Service
kubectl describe service <SERVICE_NAME>

# List Ingress resources
kubectl get ingress -A

# List Endpoints
kubectl get endpoints

# List EndpointSlices
kubectl get endpointslices

# List NetworkPolicies
kubectl get networkpolicies -A

# Forward a local port to a Service
kubectl port-forward service/<SERVICE_NAME> 8080:80
```

---

## 8. Events and Troubleshooting

```bash
# List events in the current namespace
kubectl get events

# List events across all namespaces
kubectl get events -A

# Sort events by creation timestamp
kubectl get events -A --sort-by=.metadata.creationTimestamp

# Inspect a Pod
kubectl describe pod <POD_NAME>

# View recent logs
kubectl logs <POD_NAME> --tail=100

# View previous container logs
kubectl logs <POD_NAME> --previous
```

---

## 9. Resource Monitoring, Quotas, and Limits

```bash
# Show node resource usage (requires Metrics API)
kubectl top nodes

# Show Pod resource usage
kubectl top pods

# Show Pod usage across namespaces
kubectl top pods -A

# List ResourceQuotas
kubectl get resourcequota -A

# Describe a quota
kubectl describe resourcequota <QUOTA_NAME> -n <NAMESPACE>

# List LimitRanges
kubectl get limitrange -A
```

> `kubectl top` requires Metrics Server or another compatible metrics API.

---

## 10. Storage Administration

```bash
# List StorageClasses
kubectl get storageclass

# List PersistentVolumes
kubectl get pv

# List PersistentVolumeClaims across namespaces
kubectl get pvc -A

# Describe a PVC
kubectl describe pvc <PVC_NAME> -n <NAMESPACE>

# List VolumeAttachments
kubectl get volumeattachments
```

---

## 11. ConfigMaps and Secrets

```bash
# List ConfigMaps across namespaces
kubectl get configmaps -A

# Describe a ConfigMap
kubectl describe configmap <CONFIGMAP_NAME> -n <NAMESPACE>

# List Secrets (metadata only)
kubectl get secrets -A

# Describe a Secret (avoid exposing its data)
kubectl describe secret <SECRET_NAME> -n <NAMESPACE>
```

> Avoid printing Secret values to terminals, logs, screenshots, or shared files.

---

## 12. RBAC and Access Checks

```bash
# List ServiceAccounts
kubectl get serviceaccounts -A

# List Roles
kubectl get roles -A

# List ClusterRoles
kubectl get clusterroles

# List RoleBindings
kubectl get rolebindings -A

# List ClusterRoleBindings
kubectl get clusterrolebindings

# Check whether your identity can get Pods
kubectl auth can-i get pods

# Check permissions in a namespace
kubectl auth can-i create deployments -n dev

# List permissions available to your identity
kubectl auth can-i --list
```

---

## 13. API and Resource Discovery

```bash
# List API resources
kubectl api-resources

# List API versions
kubectl api-versions

# Explain a resource
kubectl explain deployment

# Explain a specific field
kubectl explain deployment.spec

# List common resources in the current namespace
kubectl get all

# List common resources across namespaces
kubectl get all -A
```

> `kubectl get all` does not literally include every Kubernetes resource type.

---

## 14. Apply, Inspect, Diff, and Delete YAML

```bash
# Apply a manifest
kubectl apply -f deployment.yaml

# Validate a manifest with server-side dry run
kubectl apply --dry-run=server -f deployment.yaml

# View changes before applying
kubectl diff -f deployment.yaml

# Display a resource as YAML
kubectl get deployment <DEPLOYMENT_NAME> -o yaml

# Display a resource as JSON
kubectl get deployment <DEPLOYMENT_NAME> -o json

# Delete resources declared in a manifest
kubectl delete -f deployment.yaml
```

---

## 15. etcd Administration (Self-Managed Clusters Only)

**AKS note:** Azure manages the AKS control plane and etcd. Customers do not have direct access to the managed etcd instances.

In a kubeadm-based self-managed cluster, etcd commonly runs as a static Pod on a control-plane node.

### Check etcd Pods and logs

```bash
# List etcd Pods in kube-system
kubectl get pods -n kube-system | grep etcd

# Describe an etcd Pod
kubectl describe pod <ETCD_POD_NAME> -n kube-system

# View etcd logs
kubectl logs <ETCD_POD_NAME> -n kube-system
```

### Inspect the static Pod manifest

Run on the control-plane node:

```bash
sudo cat /etc/kubernetes/manifests/etcd.yaml
```

### Check etcd endpoint health

The following example assumes a kubeadm-style installation and that `etcdctl` and the listed certificates exist on the control-plane node:

```bash
sudo ETCDCTL_API=3 etcdctl \
  --endpoints=https://127.0.0.1:2379 \
  --cacert=/etc/kubernetes/pki/etcd/ca.crt \
  --cert=/etc/kubernetes/pki/etcd/healthcheck-client.crt \
  --key=/etc/kubernetes/pki/etcd/healthcheck-client.key \
  endpoint health
```

### Check endpoint status

```bash
sudo ETCDCTL_API=3 etcdctl \
  --endpoints=https://127.0.0.1:2379 \
  --cacert=/etc/kubernetes/pki/etcd/ca.crt \
  --cert=/etc/kubernetes/pki/etcd/healthcheck-client.crt \
  --key=/etc/kubernetes/pki/etcd/healthcheck-client.key \
  endpoint status --write-out=table
```

> **Caution:** etcd snapshot, restore, and membership operations are high-impact. Follow the distribution's official recovery procedure and verify backups before making changes.

---

## 16. Minikube Administration

```bash
# Show Minikube status
minikube status

# Start the cluster
minikube start

# Stop the cluster
minikube stop

# Delete the cluster
minikube delete

# List Minikube profiles
minikube profile list

# Display the Minikube cluster IP
minikube ip

# List Minikube addons
minikube addons list

# Open the Kubernetes dashboard
minikube dashboard
```

---

## 17. AKS Administration with Azure CLI

Replace placeholders with your actual resource group, cluster, and node pool names.

```bash
# List AKS clusters
az aks list --output table

# Show AKS cluster details
az aks show \
  --resource-group <RESOURCE_GROUP> \
  --name <CLUSTER_NAME> \
  --output table

# Download cluster credentials into kubeconfig
az aks get-credentials \
  --resource-group <RESOURCE_GROUP> \
  --name <CLUSTER_NAME>

# List node pools
az aks nodepool list \
  --resource-group <RESOURCE_GROUP> \
  --cluster-name <CLUSTER_NAME> \
  --output table

# Show a node pool
az aks nodepool show \
  --resource-group <RESOURCE_GROUP> \
  --cluster-name <CLUSTER_NAME> \
  --name <NODEPOOL_NAME>

# Scale a node pool
az aks nodepool scale \
  --resource-group <RESOURCE_GROUP> \
  --cluster-name <CLUSTER_NAME> \
  --name <NODEPOOL_NAME> \
  --node-count 3

# Check available Kubernetes upgrades
az aks get-upgrades \
  --resource-group <RESOURCE_GROUP> \
  --name <CLUSTER_NAME> \
  --output table
```

---

## 18. Quick Cluster Health-Check Routine

Run this sequence when beginning a cluster health investigation:

```bash
# Confirm which cluster you are connected to
kubectl config current-context

# Check cluster information
kubectl cluster-info

# Check node readiness
kubectl get nodes -o wide

# Check Pods across namespaces
kubectl get pods -A

# Review recent events
kubectl get events -A --sort-by=.metadata.creationTimestamp

# Check node and Pod metrics (requires Metrics API)
kubectl top nodes
kubectl top pods -A

# Check quotas and storage claims
kubectl get resourcequota -A
kubectl get pvc -A
```

## 19. Safety Checklist for Kubernetes Administrators

Before making changes:

1. Confirm the active context using `kubectl config current-context`.
2. Confirm the namespace with `kubectl config view --minify`.
3. Inspect the target resource using `kubectl describe`.
4. Review the impact of disruptive operations such as `drain`, `delete`, and scaling.
5. Avoid exposing kubeconfig credentials, Secret values, or sensitive cluster data.
6. For AKS control-plane or etcd issues, use Azure-supported diagnostics rather than attempting direct etcd access.

---

## Official Documentation

- Kubernetes documentation: https://kubernetes.io/docs/
- kubectl reference: https://kubernetes.io/docs/reference/kubectl/
- Minikube documentation: https://minikube.sigs.k8s.io/docs/
- AKS documentation: https://learn.microsoft.com/azure/aks/
- Azure CLI AKS reference: https://learn.microsoft.com/cli/azure/aks
