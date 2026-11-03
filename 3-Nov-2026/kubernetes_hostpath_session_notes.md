# Kubernetes `hostPath` Volume

**Session Notes \| 3 November 2026**

## 1. What Is a `hostPath` Volume?

A Kubernetes `hostPath` volume mounts a file or directory from the
worker node's filesystem into a container.

In simple terms, it allows a container inside a Pod to access a specific
path on the node where that Pod is running.

For example:

-   Worker node path: `/var/demo-data`
-   Container mount path: `/container-data`

The container sees the node's `/var/demo-data` content at
`/container-data`.

**Important:** `hostPath` does not create shared storage across
Kubernetes nodes. Each Pod accesses the path on its own node.

## 2. Why Do We Use `hostPath`?

Sometimes a Pod needs access to files or resources that exist on the
worker node rather than inside the container image.

Examples include:

-   Reading node log files.
-   Accessing selected host system directories for monitoring.
-   Giving a trusted node-level agent access to a specific host
    resource.
-   Accessing a host file or socket required by specialized
    infrastructure software.

`hostPath` is a node-local mechanism. It should be used only when there
is a clear requirement for access to the host filesystem.

## 3. How Does `hostPath` Work?

Consider this volume definition:

``` yaml
volumes:
  - name: node-data
    hostPath:
      path: /var/demo-data
      type: DirectoryOrCreate
```

And this container mount:

``` yaml
volumeMounts:
  - name: node-data
    mountPath: /container-data
```

There are three different names or paths:

  Value               Meaning
  ------------------- -------------------------------------------------
  `node-data`         Kubernetes volume name in the Pod specification
  `/var/demo-data`    Actual path on the worker node
  `/container-data`   Mount path inside the container

With `DirectoryOrCreate`, Kubernetes creates `/var/demo-data` on the
node if it does not already exist. If the directory already exists,
Kubernetes uses that directory.

The data is the same underlying node data when viewed through either
path. For example, a file created at `/container-data/demo.txt` in the
container is written to `/var/demo-data/demo.txt` on that node.

## 4. Practical Example: Deployment with Three Replicas

### Objective

Create a Deployment with three Nginx replicas. Configure every Pod to
mount `/var/demo-data` from its own worker node into the container at
`/container-data`.

We will also use required Pod anti-affinity to make the scheduler place
the three Pods on three different nodes.

**Prerequisite:** The cluster must have at least three eligible,
schedulable worker nodes. If it does not, some Pods will remain Pending
because the required anti-affinity rule cannot be satisfied.

### Deployment YAML

Save this file as `hostpath-deployment.yaml`:

``` yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: hostpath-demo
spec:
  replicas: 3

  selector:
    matchLabels:
      app: hostpath-demo

  template:
    metadata:
      labels:
        app: hostpath-demo

    spec:
      # Require each replica to run on a different node.
      affinity:
        podAntiAffinity:
          requiredDuringSchedulingIgnoredDuringExecution:
            - labelSelector:
                matchExpressions:
                  - key: app
                    operator: In
                    values:
                      - hostpath-demo
              topologyKey: kubernetes.io/hostname

      containers:
        - name: nginx
          image: nginx:1.27

          volumeMounts:
            - name: node-data
              mountPath: /container-data

      volumes:
        - name: node-data
          hostPath:
            path: /var/demo-data
            type: DirectoryOrCreate
```

### Understand the important YAML fields

**1. Three replicas**

``` yaml
replicas: 3
```

The Deployment controller tries to maintain three Pods.

**2. Required Pod anti-affinity**

``` yaml
affinity:
  podAntiAffinity:
    requiredDuringSchedulingIgnoredDuringExecution:
      - labelSelector:
          matchExpressions:
            - key: app
              operator: In
              values:
                - hostpath-demo
        topologyKey: kubernetes.io/hostname
```

This rule prevents two Pods with the label `app: hostpath-demo` from
being scheduled onto the same node, using the node hostname as the
topology boundary.

As a result, the three replicas require three different eligible nodes.

**3. `hostPath` definition**

``` yaml
volumes:
  - name: node-data
    hostPath:
      path: /var/demo-data
      type: DirectoryOrCreate
```

This tells Kubernetes to use `/var/demo-data` on the node where each Pod
is scheduled. The directory is created on that node if it does not
exist.

**4. Container mount**

``` yaml
volumeMounts:
  - name: node-data
    mountPath: /container-data
```

The container accesses the node directory through `/container-data`.

## 5. Deploy and Verify

Apply the Deployment:

``` bash
kubectl apply -f hostpath-deployment.yaml
```

Check the Pods:

``` bash
kubectl get pods -o wide
```

Check the Deployment:

``` bash
kubectl get deployment hostpath-demo
```

With at least three eligible nodes, the output should show three Pods
running on three different nodes. The exact Pod names and node names
will vary.

Example layout:

``` text
Kubernetes Cluster
|
+-- Worker Node 1
|   +-- Pod: hostpath-demo-xxxxx
|       +-- Container path: /container-data
|       +-- Node path:      /var/demo-data
|
+-- Worker Node 2
|   +-- Pod: hostpath-demo-yyyyy
|       +-- Container path: /container-data
|       +-- Node path:      /var/demo-data
|
+-- Worker Node 3
    +-- Pod: hostpath-demo-zzzzz
        +-- Container path: /container-data
        +-- Node path:      /var/demo-data
```

## 6. Does Each Node Get a Separate Directory?

Yes, if the three Pods are scheduled on three different nodes and the
directory does not already exist, `DirectoryOrCreate` creates
`/var/demo-data` independently on each respective node.

For example:

``` text
Worker Node 1:
  /var/demo-data/

Worker Node 2:
  /var/demo-data/

Worker Node 3:
  /var/demo-data/
```

These are three independent node directories. They are **not** one
shared directory.

The volume name `node-data` is the same in the Pod specifications, but
it does not make the underlying host directories shared between nodes.

### Important test: Write different files from each Pod

List the Pods and their nodes:

``` bash
kubectl get pods -l app=hostpath-demo -o wide
```

Write a file from each Pod. Replace `<pod-name>` with an actual Pod
name:

``` bash
kubectl exec <pod-name> -- sh -c \
  'echo "Data written by this Pod" > /container-data/pod-info.txt'
```

Read the file from that Pod:

``` bash
kubectl exec <pod-name> -- cat /container-data/pod-info.txt
```

If you have node access, inspect each node's directory:

``` bash
sudo ls -l /var/demo-data
sudo cat /var/demo-data/pod-info.txt
```

Run the node commands on the corresponding worker node. The file written
by a Pod is stored on the node where that Pod is running.

A file written on Worker Node 1 will not automatically appear on Worker
Node 2 or Worker Node 3.

## 7. What If a Pod Is Recreated on Another Node?

Suppose Pod 1 is deleted and its replacement is scheduled on Worker Node
2.

The replacement Pod will mount `/var/demo-data` from Worker Node 2, not
from Worker Node 1.

Consequences:

-   If the path exists on Worker Node 2, the Pod sees that node's
    existing contents.
-   If the path does not exist and the type is `DirectoryOrCreate`,
    Kubernetes creates it on Worker Node 2.
-   Data left on Worker Node 1 remains on Worker Node 1; it does not
    automatically move with the Pod.

This is why `hostPath` is not a substitute for shared or portable
persistent storage.

## 8. Common `hostPath.type` Values

  -----------------------------------------------------------------------
  Type                                Meaning
  ----------------------------------- -----------------------------------
  `""`                                No type check is performed.

  `Directory`                         The path must already exist and be
                                      a directory.

  `DirectoryOrCreate`                 Create the directory if it does not
                                      exist.

  `File`                              The path must already exist and be
                                      a file.

  `FileOrCreate`                      Create an empty file if it does not
                                      exist.

  `Socket`                            The path must already exist and be
                                      a Unix socket.

  `CharDevice`                        The path must already exist and be
                                      a character device.

  `BlockDevice`                       The path must already exist and be
                                      a block device.
  -----------------------------------------------------------------------

## 9. Industry Use Cases

### Use case 1: Node-level log collection

A cluster may run a log collector such as Fluent Bit as a DaemonSet. The
collector can mount selected host log directories and read node-level
log files.

``` text
Worker Node 1                 Worker Node 2
/var/log                      /var/log
    |                             |
    v                             v
Fluent Bit Pod                Fluent Bit Pod
    |                             |
    +-------------+---------------+
                  |
                  v
       Central Logging Platform
```

A DaemonSet is commonly used because it runs a collector Pod on each
eligible node. A `hostPath` mount can provide access to the required
host log directory.

Note: Standard container stdout/stderr logs are often collected by
node-level agents. A sidecar is another pattern for application-specific
log files, but it is not required for every logging setup.

### Use case 2: Node monitoring

A node monitoring agent, such as Node Exporter, may need access to
selected host system information, including `/proc` and `/sys`.

A carefully configured host mount can provide the required information
to the monitoring container. Exact configuration depends on the agent
and its security requirements.

### Use case 3: Specialized node-level agents

Trusted infrastructure or security agents may need access to a specific
host directory, device, or Unix socket.

A `hostPath` volume can expose that resource to the agent. This must be
tightly controlled because host access can create significant security
risks.

## 10. `emptyDir` vs `hostPath`

  -----------------------------------------------------------------------
  Feature                 `emptyDir`              `hostPath`
  ----------------------- ----------------------- -----------------------
  Purpose                 Temporary Pod-scoped    Mount a path from the
                          storage                 worker node

  Path selection          Kubernetes manages the  User specifies the node
                          volume location         path

  Pod deletion            Volume data is deleted  Host data can remain

  Node-specific           Yes                     Yes

  Shared across different No                      No
  nodes                                           

  Typical use             Temporary files, cache, Node logs, monitoring
                          sharing within a Pod    and specialized agents
  -----------------------------------------------------------------------

## 11. Important Limitations and Security Considerations

1.  **Node-specific data:** Each node has its own filesystem. The same
    path on different nodes does not represent the same storage.
2.  **Pod rescheduling:** If a Pod moves to another node, it accesses
    the path on the new node.
3.  **Security risk:** Exposing host files can reveal sensitive
    information or allow changes to the node.
4.  **Read-only mounts:** Use `readOnly: true` when the application only
    needs to read host data.
5.  **Least privilege:** Mount only the specific host path that is
    required. Avoid mounting the entire host root filesystem.
6.  **Production storage:** Do not normally use `hostPath` for databases
    or application data that must survive node replacement or be
    available across nodes.
7.  **Managed Kubernetes:** In AKS, EKS, and GKE, direct worker-node
    access may be restricted. Use supported node access and debugging
    procedures.

## 12. Cleanup

Delete the Deployment:

``` bash
kubectl delete deployment hostpath-demo
```

Deleting the Pods does not necessarily delete the `/var/demo-data`
directories or files from the worker nodes. `hostPath` data is host
data, so inspect and clean it up on the relevant nodes if required.

## 13. Interview Questions

### Q1. What is a `hostPath` volume?

A `hostPath` volume mounts a file or directory from the worker node's
filesystem into a container.

### Q2. If three Pods run on three different nodes and use the same `hostPath` path, do they share the same data?

No. Each Pod accesses the specified path on its own node. The
directories are independent unless some separate storage mechanism makes
the underlying data shared.

### Q3. Does Kubernetes create a directory for `hostPath`?

It depends on the configured type. With `DirectoryOrCreate`, Kubernetes
creates the specified directory on the node if it does not exist. With
`Directory`, the directory must already exist.

### Q4. What happens if a Pod using `hostPath` is rescheduled to another node?

The Pod mounts the specified path on the new node. It does not
automatically carry data from the previous node.

### Q5. Why is `hostPath` used with DaemonSets?

DaemonSets commonly run node-level agents, such as log collectors and
monitoring agents, on each eligible node. `hostPath` can give those
agents access to selected node resources.

### Q6. Is `hostPath` recommended for production databases?

Usually no. It ties data to a specific node and does not provide
portable, shared, or highly available storage by itself. A suitable
CSI-backed PersistentVolume is generally a better choice.

## 14. Session Summary

Remember these points:

-   `hostPath` exposes a worker node file or directory to a container.
-   `hostPath.path` is the actual path on the node.
-   `volumeMounts.mountPath` is the path inside the container.
-   `DirectoryOrCreate` creates the directory on each node where a Pod
    uses it, if it does not already exist.
-   Three Pods on three nodes use three independent node-local
    directories.
-   The same path on different nodes does not mean shared storage.
-   Common uses include node log collection, node monitoring, and
    specialized node-level agents.
-   Use PVCs and suitable CSI storage for application data that needs
    persistence independent of a particular node.

**Key interview statement:**

"`hostPath` is a node-local Kubernetes volume that mounts a file or
directory from the worker node into a Pod. If Pods are scheduled on
different nodes, each Pod accesses the specified path on its own node.
It is useful for node-level agents, but it does not provide shared
storage across nodes."
