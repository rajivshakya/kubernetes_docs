# Kubernetes `emptyDir` Volume

**Session Notes \| 3 November 2026**

## 1. What Is an `emptyDir` Volume?

`emptyDir` is an ephemeral Kubernetes volume created for a Pod after the
Pod is assigned to a node.

It provides a temporary directory that can be mounted by one or more
containers in the same Pod.

In simple terms:

-   Kubernetes creates an `emptyDir` volume for the Pod.
-   Containers in that Pod can mount the same volume at different paths.
-   Containers can read and write the same underlying files.
-   The data normally remains available across container restarts while
    the same Pod exists.
-   When the Pod is removed from the node, the `emptyDir` data is
    deleted.

**Important:** `emptyDir` is Pod-scoped, not a persistent storage
solution. A replacement Pod gets a new, empty volume.

## 2. Why Do We Use `emptyDir`?

Containers have separate filesystems. Sometimes two or more containers
in one Pod need to exchange files or access the same temporary
workspace.

`emptyDir` solves this problem without requiring an external persistent
storage system.

Common reasons to use it:

-   Share temporary files between containers in a Pod.
-   Provide a temporary workspace for build or processing jobs.
-   Store cache data that can be recreated.
-   Share application log files with a log-processing sidecar.
-   Provide scratch space for short-lived data processing.

## 3. How Does `emptyDir` Work?

Consider this definition:

``` yaml
volumes:
  - name: shared-storage
    emptyDir: {}
```

This creates one Pod-scoped volume named `shared-storage`.

Now mount it into two containers:

``` yaml
containers:
  - name: container-1
    image: nginx
    volumeMounts:
      - name: shared-storage
        mountPath: /data

  - name: container-2
    image: busybox
    command: ["sh", "-c", "sleep 3600"]
    volumeMounts:
      - name: shared-storage
        mountPath: /backup
```

There are three important values:

  Value              Meaning
  ------------------ -------------------------------
  `shared-storage`   Kubernetes volume name
  `/data`            Mount path inside Container 1
  `/backup`          Mount path inside Container 2

Both mount paths point to the same underlying volume.

A file created at `/data/demo.txt` in Container 1 is visible as
`/backup/demo.txt` in Container 2.

## 4. Practical Example: Two Containers Sharing One `emptyDir`

### Objective

Create one Pod with two containers:

-   Container 1: Nginx.
-   Container 2: BusyBox.
-   Both containers mount the same `emptyDir` volume.
-   Container 1 writes a file.
-   Container 2 reads the same file.

### Complete Pod YAML

Save as `emptydir-pod.yaml`:

``` yaml
apiVersion: v1
kind: Pod
metadata:
  name: shared-volume-pod

spec:
  containers:

    # First container
    - name: container-1
      image: nginx

      volumeMounts:
        - name: shared-storage
          mountPath: /data

    # Second container
    - name: container-2
      image: busybox
      command: ["sh", "-c", "sleep 3600"]

      volumeMounts:
        - name: shared-storage
          mountPath: /backup

  # Pod-level volume definition
  volumes:
    - name: shared-storage
      emptyDir: {}
```

### Understand the YAML

**1. Define the volume**

``` yaml
volumes:
  - name: shared-storage
    emptyDir: {}
```

Kubernetes creates an empty volume for this Pod.

**2. Mount it in Container 1**

``` yaml
volumeMounts:
  - name: shared-storage
    mountPath: /data
```

Container 1 accesses the volume through `/data`.

**3. Mount the same volume in Container 2**

``` yaml
volumeMounts:
  - name: shared-storage
    mountPath: /backup
```

Container 2 accesses the same volume through `/backup`.

The mount paths are different, but the underlying storage is the same.

## 5. Deploy and Test

Create the Pod:

``` bash
kubectl apply -f emptydir-pod.yaml
```

Check its status:

``` bash
kubectl get pod shared-volume-pod -o wide
```

Check both containers:

``` bash
kubectl get pod shared-volume-pod \
  -o jsonpath='{.spec.containers[*].name}'
```

### Step 1: Write a file from Container 1

``` bash
kubectl exec shared-volume-pod -c container-1 -- sh -c \
  'echo "Hello Kubernetes" > /data/demo.txt'
```

### Step 2: Read the same file from Container 2

``` bash
kubectl exec shared-volume-pod -c container-2 -- \
  cat /backup/demo.txt
```

Expected output:

``` text
Hello Kubernetes
```

### Step 3: Write a file from Container 2

``` bash
kubectl exec shared-volume-pod -c container-2 -- sh -c \
  'echo "Written by Container 2" > /backup/second.txt'
```

### Step 4: Read it from Container 1

``` bash
kubectl exec shared-volume-pod -c container-1 -- \
  cat /data/second.txt
```

Expected output:

``` text
Written by Container 2
```

This confirms that both containers are accessing the same underlying
volume.

## 6. Where Is `emptyDir` Stored on the Worker Node?

By default, `emptyDir` normally uses node-local storage.

On many Linux Kubernetes nodes, a typical kubelet-managed path is:

``` text
/var/lib/kubelet/pods/<POD-UID>/volumes/kubernetes.io~empty-dir/<VOLUME-NAME>/
```

For our example, the volume-name portion is:

``` text
shared-storage
```

The path is implementation-specific and should not be treated as a
Kubernetes API guarantee. It can vary by Kubernetes distribution, node
configuration, runtime, and managed Kubernetes service.

### Find the Pod UID

``` bash
kubectl get pod shared-volume-pod \
  -o jsonpath='{.metadata.uid}'
```

### Find the node

``` bash
kubectl get pod shared-volume-pod -o wide
```

If you have access to the worker node, you can inspect the typical
kubelet directory:

``` bash
sudo ls -l /var/lib/kubelet/pods/
```

Then inspect the relevant Pod UID and volume directory.

**Important:** The volume name `shared-storage` is the logical name in
the Pod specification. Containers see the volume at their configured
mount paths, `/data` and `/backup`.

## 7. `emptyDir` Lifecycle

Understanding the lifecycle is essential.

  -----------------------------------------------------------------------
  Event                               What happens to `emptyDir` data?
  ----------------------------------- -----------------------------------
  Container restart                   Data normally remains

  Container crash                     Data normally remains while the
                                      same Pod exists

  Same Pod container recreation       Data remains

  Pod deletion                        Data is deleted

  Replacement Pod creation            A new empty volume is created

  Pod rescheduled as a new Pod on     New Pod gets a new `emptyDir`
  another node                        
  -----------------------------------------------------------------------

### Important distinction: Container restart vs Pod recreation

A container can restart inside the same Pod. The Pod UID remains the
same, so its `emptyDir` data normally remains.

If a Deployment replaces a deleted or failed Pod, it creates a new Pod
object. The new Pod receives a new `emptyDir`, so the old Pod's data is
not carried over.

## 8. Memory-backed `emptyDir`

By default, `emptyDir` uses the node's local storage. It can also use
memory-backed storage.

Example:

``` yaml
apiVersion: v1
kind: Pod
metadata:
  name: memory-volume-pod

spec:
  containers:
    - name: app
      image: nginx

      volumeMounts:
        - name: memory-storage
          mountPath: /cache

  volumes:
    - name: memory-storage
      emptyDir:
        medium: Memory
        sizeLimit: 256Mi
```

### What happens here?

-   `medium: Memory` tells Kubernetes to use a memory-backed filesystem
    (`tmpfs`).
-   The volume is mounted inside the container at `/cache`.
-   `sizeLimit` sets a limit for the volume's size.

### Use cases

-   Temporary in-memory file processing.
-   Short-lived cache.
-   Temporary data exchange where memory-backed storage is appropriate.

**Memory consideration:** Data stored in a memory-backed `emptyDir`
consumes memory. Plan container memory limits and Pod resource usage
carefully. It is not durable storage.

## 9. Industry Use Cases

### Use case 1: Application Logging with a Sidecar

Suppose an application writes logs to files, and a Fluent Bit sidecar
needs to read and forward those logs.

One Pod contains:

-   Application container: Writes log files.
-   Fluent Bit container: Reads log files and forwards them to a
    centralized logging system.
-   `emptyDir`: Shared temporary log directory.

``` text
             Kubernetes Pod
          ______________________
         |                      |
         | Application Container|
         |          |           |
         |          | Writes    |
         |          v           |
         |       emptyDir       |
         |          |           |
         |          | Reads     |
         |          v           |
         | Fluent Bit Sidecar   |
         |______________________|
                    |
                    v
          Central Logging System
```

The application might mount the volume at `/var/log/app`, while Fluent
Bit mounts it at `/logs`.

Example volume mounts:

``` yaml
containers:
  - name: app
    image: example/app:v1
    volumeMounts:
      - name: shared-logs
        mountPath: /var/log/app

  - name: fluent-bit
    image: fluent/fluent-bit:3.2
    volumeMounts:
      - name: shared-logs
        mountPath: /logs
        readOnly: true

volumes:
  - name: shared-logs
    emptyDir: {}
```

The application writes files to `/var/log/app`, and Fluent Bit reads the
same files from `/logs`.

**Production note:** Standard container stdout/stderr logs are commonly
collected by node-level logging agents deployed as DaemonSets. A sidecar
with `emptyDir` is useful when the application specifically writes log
files that another container must process.

### Use case 2: CI/CD Build Workspace

Suppose a Kubernetes-based CI/CD job uses multiple containers in one
Pod:

-   Container 1: Checks out source code from Git.
-   Container 2: Builds the application using Maven.
-   Container 3: Runs a code scan.

All containers need access to the same source code and build artifacts.

``` text
Git Checkout Container
         |
         | Source code
         v
      emptyDir
         |
         +------> Maven Build Container
         |
         +------> Code Scan Container
```

The containers can mount the same volume at paths such as `/workspace`.

Once the CI/CD job is complete and its Pod is removed, the temporary
workspace can be discarded.

### Use case 3: Temporary File Processing

Suppose an application receives a CSV file that needs to be processed.

-   Container 1 downloads the file.
-   Container 2 processes the file.
-   Container 3 uploads the final output to Azure Blob Storage or Amazon
    S3.

``` text
Download Container
        |
        v
     emptyDir
        |
        v
 Processing Container
        |
        v
     emptyDir
        |
        v
 Upload Container
        |
        v
 Cloud Object Storage
```

The temporary working files do not need to survive Pod deletion because
the final output is stored in durable object storage.

## 10. `emptyDir` vs `hostPath`

  -----------------------------------------------------------------------
  Feature                 `emptyDir`              `hostPath`
  ----------------------- ----------------------- -----------------------
  Purpose                 Temporary storage for a Mount a node file or
                          Pod                     directory

  Path                    Managed by Kubernetes   Specified by the user

  Pod deletion            Data is deleted         Host data can remain

  Container sharing       Yes, within the same    Yes, within the same
                          Pod                     Pod

  Node-specific           Yes                     Yes

  Common use              Cache, temporary files, Node logs, monitoring,
                          shared workspace        specialized node agents
  -----------------------------------------------------------------------

## 11. `emptyDir` vs PersistentVolume

  -----------------------------------------------------------------------
  Feature                 `emptyDir`              PVC-backed storage
  ----------------------- ----------------------- -----------------------
  Purpose                 Temporary Pod data      Data that should
                                                  outlive an individual
                                                  Pod

  Pod deletion            Data is deleted         Data can remain

  Storage provisioning    Created for the Pod     Uses a PV or dynamic
                                                  provisioning

  Common use              Cache, scratch files,   Database files,
                          temporary workspace     persistent uploads,
                                                  application data

  Durable backup          No                      Requires a separate
                                                  backup strategy
  -----------------------------------------------------------------------

## 12. Important Limitations and Best Practices

1.  Use `emptyDir` only when data can be discarded after the Pod is
    removed.
2.  Do not use it as the only storage for important database data.
3.  Set `sizeLimit` when a workload needs a bounded temporary volume.
4.  Set suitable Pod resource requests and limits, especially for
    memory-backed volumes.
5.  Remember that `emptyDir` is local to one Pod and does not share data
    between different Pods.
6.  If a Pod is recreated, its new `emptyDir` starts empty.
7.  For data that must survive Pod deletion, use a suitable
    PersistentVolumeClaim or external storage.
8.  For concurrent writes to shared files, make sure the application
    handles synchronization and file consistency.

## 13. Troubleshooting Commands

``` bash
# List Pods
kubectl get pods -o wide

# Describe Pod and inspect its volumes and mounts
kubectl describe pod shared-volume-pod

# Inspect volume definitions
kubectl get pod shared-volume-pod -o yaml

# Inspect the mount from Container 1
kubectl exec shared-volume-pod -c container-1 -- df -h /data

# Inspect the mount from Container 2
kubectl exec shared-volume-pod -c container-2 -- df -h /backup

# Inspect files from Container 1
kubectl exec shared-volume-pod -c container-1 -- ls -l /data

# Inspect files from Container 2
kubectl exec shared-volume-pod -c container-2 -- ls -l /backup
```

## 14. Cleanup

Delete the Pod:

``` bash
kubectl delete pod shared-volume-pod
```

After Pod deletion, Kubernetes removes the Pod's `emptyDir` volume data.

## 15. Interview Questions and Answers

### Q1. What is an `emptyDir` volume?

An `emptyDir` is an ephemeral volume created for a Pod when it is
assigned to a node. It can be shared by multiple containers in that Pod.

### Q2. Does `emptyDir` survive a container restart?

Yes. Its data normally remains while the same Pod exists, even if a
container restarts.

### Q3. What happens when a Pod is deleted?

The `emptyDir` data is deleted. A replacement Pod gets a new empty
volume.

### Q4. Can multiple containers share the same `emptyDir`?

Yes. Multiple containers in the same Pod can mount the same volume at
different paths and access the same underlying files.

### Q5. Is `emptyDir` stored on the worker node?

By default, it normally uses node-local storage. With `medium: Memory`,
it uses a memory-backed filesystem.

### Q6. Can different Pods share the same `emptyDir`?

No. An `emptyDir` belongs to one Pod. Different Pods get separate
`emptyDir` volumes.

### Q7. What is the difference between `emptyDir` and `hostPath`?

`emptyDir` is a temporary volume managed for a Pod. `hostPath` mounts a
specific path from the worker node's filesystem.

### Q8. Can we use `emptyDir` for a database?

It can be used for temporary database files or scratch space, but not as
the only storage for data that must survive Pod deletion.

## 16. Session Summary

Remember these key points:

-   `emptyDir` is an ephemeral, Pod-scoped volume.
-   Kubernetes creates it when the Pod is assigned to a node.
-   By default, it normally uses node-local storage.
-   Multiple containers in the same Pod can share it.
-   Each container can mount it at a different `mountPath`.
-   Container restarts do not normally remove its data.
-   Pod deletion removes the volume and its data.
-   `medium: Memory` creates a memory-backed `tmpfs` volume.
-   Common use cases include sidecar log processing, CI/CD workspaces,
    temporary file processing, and cache.

**Key interview statement:**

"`emptyDir` is an ephemeral Kubernetes volume created for a Pod when it
is assigned to a node. It allows multiple containers within the same Pod
to share temporary data. Its data survives container restarts while the
same Pod exists, but is deleted when the Pod is removed."
