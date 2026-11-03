# Kubernetes Volumes and Storage

**Session Notes \| 3 November 2026**

## 1. Why Does Kubernetes Need Volumes?

A container has its own filesystem. Data written only to a container's
writable layer is not a reliable way to store application data
permanently. When a container is recreated, its writable-layer data is
lost.

Kubernetes volumes provide storage to containers in a Pod. Depending on
the volume type, data may be:

-   Shared between containers in the same Pod.
-   Temporary and tied to the Pod's lifecycle.
-   Stored on a node.
-   Backed by external or network storage and retained beyond the Pod's
    lifecycle.

**Important:** A Kubernetes volume is not automatically persistent.
Persistence depends on the volume type and its backing storage.

## 2. Important Terms

  -----------------------------------------------------------------------
  Term                                Meaning
  ----------------------------------- -----------------------------------
  Volume                              A storage resource made available
                                      to containers in a Pod.

  `volumes`                           Pod specification section where
                                      volumes are defined.

  `volumeMounts`                      Container specification section
                                      that defines where a volume is
                                      mounted.

  `mountPath`                         Directory inside the container
                                      where the volume is made available.

  PV                                  PersistentVolume, a cluster storage
                                      resource.

  PVC                                 PersistentVolumeClaim, a request
                                      for storage.

  StorageClass                        Defines a class of storage and how
                                      it can be provisioned.

  CSI                                 Container Storage Interface, the
                                      standard used by storage drivers to
                                      integrate storage systems with
                                      Kubernetes.
  -----------------------------------------------------------------------

A volume name in the Pod specification is a Kubernetes reference. It is
not necessarily the directory name visible inside a container. The
container sees the volume at the configured `mountPath`.

Example:

``` yaml
volumes:
  - name: shared-storage
    emptyDir: {}

containers:
  - name: app
    image: nginx
    volumeMounts:
      - name: shared-storage
        mountPath: /data
```

Here:

-   `shared-storage` is the volume name in the Pod specification.
-   `/data` is the mount path inside the container.

## 3. Main Categories of Kubernetes Volumes

Kubernetes storage can be understood in two broad groups:

1.  **Ephemeral volumes:** Their lifecycle is tied to a Pod. They are
    useful for temporary data, caches, scratch space, and sharing files
    between containers.
2.  **Persistent storage:** Designed to keep data independently of an
    individual Pod's lifecycle. Commonly implemented using
    PersistentVolumes, PersistentVolumeClaims, StorageClasses, and CSI
    drivers.

Kubernetes also provides several built-in volume sources, such as
`configMap`, `secret`, `projected`, and `downwardAPI`. These are useful
for presenting configuration or metadata to containers; they are not
general-purpose database storage.

## 4. `emptyDir` Volume

### What is `emptyDir`?

`emptyDir` is an ephemeral volume created for a Pod after the Pod is
assigned to a node. It starts empty and can be mounted by one or more
containers in that Pod.

The underlying data is normally stored on the node's local storage. If
configured with `medium: Memory`, Kubernetes uses a memory-backed
`tmpfs` filesystem instead.

### Lifecycle

-   A container restart does not normally remove the Pod's `emptyDir`
    data.
-   The data remains available while the same Pod object exists.
-   When the Pod is removed from the node, its `emptyDir` data is
    deleted.
-   A newly created Pod gets a new, empty `emptyDir`, even if it has the
    same name as the old Pod.

### Example: Two containers sharing one `emptyDir`

Save as `emptydir-pod.yaml`:

``` yaml
apiVersion: v1
kind: Pod
metadata:
  name: shared-volume-pod
spec:
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

  volumes:
    - name: shared-storage
      emptyDir: {}
```

In this example:

-   The Pod defines one volume named `shared-storage`.
-   Container 1 mounts it at `/data`.
-   Container 2 mounts the same volume at `/backup`.
-   A file written to `/data` by Container 1 is visible at `/backup` in
    Container 2.

### Practical commands

``` bash
kubectl apply -f emptydir-pod.yaml
kubectl get pod shared-volume-pod -o wide
kubectl exec shared-volume-pod -c container-1 -- sh -c 'echo "Hello Kubernetes" > /data/demo.txt'
kubectl exec shared-volume-pod -c container-2 -- cat /backup/demo.txt
```

Expected output:

``` text
Hello Kubernetes
```

Create a file from the second container and read it from the first:

``` bash
kubectl exec shared-volume-pod -c container-2 -- sh -c 'echo "Written by container 2" > /backup/second.txt'
kubectl exec shared-volume-pod -c container-1 -- cat /data/second.txt
```

Inspect the mount from inside a container:

``` bash
kubectl exec shared-volume-pod -c container-1 -- df -h /data
kubectl exec shared-volume-pod -c container-1 -- mount | grep /data
```

Clean up:

``` bash
kubectl delete pod shared-volume-pod
```

### Where is `emptyDir` stored on the node?

On many Linux Kubernetes nodes, a typical kubelet-managed path is:

``` text
/var/lib/kubelet/pods/<POD-UID>/volumes/kubernetes.io~empty-dir/<VOLUME-NAME>/
```

For the example above, the volume-name portion is `shared-storage`.

This is a common implementation path, not a Kubernetes API guarantee.
The actual location can differ by distribution, node configuration,
runtime, and managed Kubernetes service. In managed services, direct
node access may not be available.

### `emptyDir` backed by memory

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

`medium: Memory` uses a memory-backed filesystem (`tmpfs`). Data
consumes memory, so size limits and container memory limits should be
planned carefully. Do not use it as durable storage.

### Common `emptyDir` use cases

1.  **Sidecar log processing:** An application writes log files to a
    shared volume and a sidecar reads and forwards them. In many
    clusters, node-level log collection with a DaemonSet is preferred
    for standard container stdout/stderr logs; a sidecar is useful when
    application-specific file processing is required.
2.  **CI/CD workspace:** Build and scanning containers share source code
    or temporary build artifacts. The workspace is discarded when the
    job Pod is removed.
3.  **Temporary processing or cache:** A worker downloads files,
    processes them, and uploads the final result to durable object
    storage. Temporary files can be discarded afterwards.

## 5. `hostPath` Volume

### What is `hostPath`?

`hostPath` mounts a file or directory from the worker node's filesystem
into a container.

Unlike `emptyDir`, which Kubernetes creates for a Pod, `hostPath` refers
to a path that exists on the node (or can be created depending on
`type`).

### Example

Save as `hostpath-pod.yaml`:

``` yaml
apiVersion: v1
kind: Pod
metadata:
  name: hostpath-demo
spec:
  containers:
    - name: app
      image: nginx
      volumeMounts:
        - name: node-data
          mountPath: /container-data
  volumes:
    - name: node-data
      hostPath:
        path: /var/demo-data
        type: DirectoryOrCreate
```

Kubernetes mounts the node directory `/var/demo-data` inside the
container at `/container-data`.

Test:

``` bash
kubectl apply -f hostpath-pod.yaml
kubectl exec hostpath-demo -- sh -c 'echo "Hello from Pod" > /container-data/demo.txt'
```

If you can access the worker node, inspect:

``` bash
sudo ls -l /var/demo-data
sudo cat /var/demo-data/demo.txt
```

### Common `hostPath.type` values

  Type                  Meaning
  --------------------- -------------------------------------------------
  `""`                  No type check is performed.
  `Directory`           The path must already exist and be a directory.
  `DirectoryOrCreate`   Create the directory if it does not exist.
  `File`                The path must already exist and be a file.
  `FileOrCreate`        Create an empty file if it does not exist.

### Important limitations and risks

-   A Pod using `hostPath` is tied to the node's local filesystem path.
-   If the Pod is rescheduled to another node, that node may have
    different or empty data at the same path.
-   `hostPath` can expose sensitive node files to a container.
-   It is generally unsuitable as a portable, highly available
    application database storage solution.
-   Use it only when there is a clear node-level requirement and access
    is tightly controlled.

Typical use cases include node-level agents that need access to host
logs or specific host files. For cluster-wide log collection, a
DaemonSet is a common pattern.

## 6. Ephemeral Volumes

The word **ephemeral** means temporary or short-lived. An ephemeral
volume is associated with a Pod's lifecycle rather than being intended
as independent durable storage.

Kubernetes includes several ephemeral volume patterns:

### 6.1 `emptyDir`

A simple Pod-scoped temporary directory. It is created for the Pod and
removed when the Pod is removed.

### 6.2 ConfigMap and Secret volumes

These project configuration or sensitive values into a Pod as files.

ConfigMap example:

``` yaml
apiVersion: v1
kind: Pod
metadata:
  name: config-volume-demo
spec:
  containers:
    - name: app
      image: nginx
      volumeMounts:
        - name: app-config
          mountPath: /etc/app-config
          readOnly: true
  volumes:
    - name: app-config
      configMap:
        name: app-settings
```

Create the ConfigMap:

``` bash
kubectl create configmap app-settings \
  --from-literal=APP_MODE=production
```

The key is projected as a file under `/etc/app-config` (for this
example, `/etc/app-config/APP_MODE`).

Secret volume example:

``` yaml
apiVersion: v1
kind: Pod
metadata:
  name: secret-volume-demo
spec:
  containers:
    - name: app
      image: nginx
      volumeMounts:
        - name: app-secret
          mountPath: /etc/app-secret
          readOnly: true
  volumes:
    - name: app-secret
      secret:
        secretName: app-credentials
```

Create a sample Secret for a lab:

``` bash
kubectl create secret generic app-credentials \
  --from-literal=username=demo-user \
  --from-literal=password='change-me'
```

**Security note:** Kubernetes Secrets are not automatically encrypted in
every cluster configuration. Enable encryption at rest, restrict RBAC
access, and avoid committing real credentials to source control.

### 6.3 Generic ephemeral volumes

A generic ephemeral volume lets a Pod use a PVC template embedded in its
Pod specification. Kubernetes manages the generated PVC as part of the
Pod's ephemeral-volume lifecycle. The backing storage may be dynamically
provisioned by a StorageClass.

Example:

``` yaml
apiVersion: v1
kind: Pod
metadata:
  name: generic-ephemeral-demo
spec:
  containers:
    - name: app
      image: nginx
      volumeMounts:
        - name: scratch-disk
          mountPath: /scratch
  volumes:
    - name: scratch-disk
      ephemeral:
        volumeClaimTemplate:
          metadata:
            labels:
              purpose: scratch
          spec:
            accessModes:
              - ReadWriteOnce
            storageClassName: standard
            resources:
              requests:
                storage: 1Gi
```

This requires a compatible StorageClass named `standard`. The volume is
intended to be ephemeral from the Pod's perspective, even though the
backing storage may be a dynamically provisioned persistent-storage
resource.

## 7. Persistent Storage: Why Is It Needed?

Consider a PostgreSQL database running in a Pod.

If database files are stored only in the container's writable layer or
an `emptyDir`, deleting the Pod can result in data loss.

For databases, uploads, and other important application data, storage
should be independent of the individual Pod lifecycle.

Kubernetes commonly uses these objects:

-   PersistentVolume (PV)
-   PersistentVolumeClaim (PVC)
-   StorageClass (SC)
-   CSI storage driver

## 8. PersistentVolume (PV)

A PersistentVolume is a cluster-level resource representing storage made
available to the Kubernetes cluster.

It can represent storage from systems such as:

-   AWS EBS
-   AWS EFS
-   Azure Disk
-   Azure Files
-   Google Persistent Disk
-   NFS
-   Other CSI-supported storage systems

A PV describes properties such as capacity, access modes, reclaim
policy, storage class, and the storage source or CSI volume handle.

### Example: Static PV using `hostPath` for learning only

The following example is suitable only for a single-node learning lab.
It is not a production storage design.

``` yaml
apiVersion: v1
kind: PersistentVolume
metadata:
  name: demo-pv
spec:
  capacity:
    storage: 2Gi
  volumeMode: Filesystem
  accessModes:
    - ReadWriteOnce
  persistentVolumeReclaimPolicy: Retain
  storageClassName: manual
  hostPath:
    path: /mnt/data/demo-pv
    type: DirectoryOrCreate
```

Apply and inspect:

``` bash
kubectl apply -f pv.yaml
kubectl get pv
kubectl describe pv demo-pv
```

`hostPath` is used here only to demonstrate PV/PVC binding. For
multi-node or production clusters, use an appropriate CSI-backed storage
solution.

## 9. PersistentVolumeClaim (PVC)

A PersistentVolumeClaim is a request for storage made by a user or
application.

A PVC can request:

-   Storage capacity.
-   Access mode.
-   Volume mode.
-   A particular StorageClass.

Kubernetes attempts to bind the PVC to a suitable PV. The requested
capacity must be satisfied by the selected PV, and the other matching
requirements must also be compatible.

### Example PVC

Save as `pvc.yaml`:

``` yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: demo-pvc
spec:
  accessModes:
    - ReadWriteOnce
  storageClassName: manual
  resources:
    requests:
      storage: 1Gi
```

Apply and inspect:

``` bash
kubectl apply -f pvc.yaml
kubectl get pvc
kubectl get pv
```

The 1Gi claim can bind to the 2Gi PV in the static example, assuming the
other requirements match.

### PV and PVC relationship

``` text
Application Pod
      |
      | references
      v
     PVC  (requests storage)
      |
      | binds to
      v
      PV  (represents storage)
      |
      v
Actual storage backend
```

A PV and PVC normally have a one-to-one binding. A PVC does not normally
split across several PVs.

## 10. Mount a PVC into a Pod

Save as `pvc-pod.yaml`:

``` yaml
apiVersion: v1
kind: Pod
metadata:
  name: pvc-demo-pod
spec:
  containers:
    - name: app
      image: nginx
      volumeMounts:
        - name: persistent-storage
          mountPath: /usr/share/nginx/html
  volumes:
    - name: persistent-storage
      persistentVolumeClaim:
        claimName: demo-pvc
```

Apply:

``` bash
kubectl apply -f pvc-pod.yaml
kubectl get pod pvc-demo-pod
```

Write a file:

``` bash
kubectl exec pvc-demo-pod -- sh -c \
  'echo "Persistent data" > /usr/share/nginx/html/index.html'
```

Read it:

``` bash
kubectl exec pvc-demo-pod -- cat /usr/share/nginx/html/index.html
```

Delete the Pod:

``` bash
kubectl delete pod pvc-demo-pod
```

Recreate it:

``` bash
kubectl apply -f pvc-pod.yaml
kubectl exec pvc-demo-pod -- cat /usr/share/nginx/html/index.html
```

If the PVC and backing volume remain available, the data should still be
present.

**Important:** A Pod can be recreated and use the same PVC, but the
volume must be attachable/mountable on the new node. Storage topology,
access modes, CSI driver behaviour, and node availability can affect
scheduling and attachment.

## 11. StorageClass (SC)

A StorageClass describes a class of storage and the provisioner and
parameters used to create it.

It enables dynamic provisioning: when a PVC requests a StorageClass,
Kubernetes can ask the configured storage provisioner to create suitable
storage and a PV.

Without dynamic provisioning, an administrator may need to create PVs
manually (static provisioning).

### Example StorageClass for AKS Azure Disk CSI

This is an illustrative example. Confirm that the Azure Disk CSI driver
is available and that the selected SKU and parameters are supported in
your AKS region and configuration.

``` yaml
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: managed-csi-standard
provisioner: disk.csi.azure.com
parameters:
  skuName: StandardSSD_LRS
reclaimPolicy: Delete
volumeBindingMode: WaitForFirstConsumer
allowVolumeExpansion: true
```

Important fields:

  -----------------------------------------------------------------------
  Field                               Meaning
  ----------------------------------- -----------------------------------
  `provisioner`                       CSI or other provisioner
                                      responsible for provisioning
                                      storage.

  `parameters`                        Storage-provider-specific settings,
                                      such as disk SKU.

  `reclaimPolicy`                     What happens to the backing storage
                                      after the PVC is deleted.

  `volumeBindingMode`                 When PV binding and provisioning
                                      should happen.

  `allowVolumeExpansion`              Whether supported claims can be
                                      expanded.
  -----------------------------------------------------------------------

### `volumeBindingMode`

-   `Immediate`: Provision or bind storage as soon as the PVC is
    created.
-   `WaitForFirstConsumer`: Delay provisioning/binding until a Pod using
    the PVC is scheduled. This helps the scheduler consider topology
    constraints.

### Dynamic provisioning PVC example

``` yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: azure-disk-pvc
spec:
  accessModes:
    - ReadWriteOnce
  storageClassName: managed-csi-standard
  resources:
    requests:
      storage: 10Gi
```

Apply and inspect:

``` bash
kubectl apply -f storageclass.yaml
kubectl apply -f azure-disk-pvc.yaml
kubectl get storageclass
kubectl get pvc
kubectl get pv
```

With `WaitForFirstConsumer`, the PVC may remain `Pending` until a Pod
that uses it is scheduled.

## 12. Static vs Dynamic Provisioning

  -----------------------------------------------------------------------
  Feature                 Static provisioning     Dynamic provisioning
  ----------------------- ----------------------- -----------------------
  PV creation             Administrator creates   Provisioner creates PV
                          PV first                when needed

  PVC                     Application requests    Application requests
                          storage                 storage

  StorageClass            May use a class or no   Normally selects a
                          class                   StorageClass

  Operational effort      More manual             More automated

  Common usage            Pre-existing storage or Common cloud-native
                          controlled allocation   application storage
  -----------------------------------------------------------------------

## 13. Reclaim Policies: `Retain` and `Delete`

The reclaim policy controls what happens to the underlying storage when
a PVC is deleted and the PV is released.

### `Retain`

-   The PV and underlying storage are retained for manual recovery or
    cleanup.
-   The PV generally enters a `Released` state after its claim is
    deleted.
-   An administrator must inspect and handle the data and PV before
    reuse.

### `Delete`

-   The PV and its backing storage may be deleted by the provisioner
    when the claim is released.
-   The exact behaviour depends on the volume plugin or CSI driver.

**Production warning:** Understand reclaim policy before deleting PVCs.
A PVC deletion can lead to permanent data loss when the reclaim policy
is `Delete`.

## 14. Access Modes

  -----------------------------------------------------------------------
  Access mode                         Meaning
  ----------------------------------- -----------------------------------
  `ReadWriteOnce` (RWO)               Volume can be mounted read-write by
                                      a single node. Multiple Pods on
                                      that same node may be able to use
                                      it, subject to driver and
                                      filesystem constraints.

  `ReadOnlyMany` (ROX)                Volume can be mounted read-only by
                                      multiple nodes, if supported by the
                                      driver.

  `ReadWriteMany` (RWX)               Volume can be mounted read-write by
                                      multiple nodes, if supported by the
                                      driver.

  `ReadWriteOncePod` (RWOP)           Volume can be mounted read-write by
                                      a single Pod, subject to CSI
                                      support and Kubernetes version
                                      requirements.
  -----------------------------------------------------------------------

Do not interpret RWO as "only one Pod". It refers to a single node, not
necessarily a single Pod.

Examples often seen in cloud environments:

-   Azure Disk: commonly used for RWO workloads.
-   Azure Files: can support RWX scenarios.
-   AWS EBS: commonly used for RWO workloads.
-   AWS EFS: commonly used for RWX workloads.

Always verify the access modes supported by the selected CSI driver and
storage service.

## 15. Volume Modes

A PV can be exposed in one of two modes:

-   `Filesystem` (default): A filesystem is mounted into the container.
-   `Block`: A raw block device is presented to the container. The
    application must manage the block device appropriately.

Most typical application workloads use `Filesystem`.

## 16. CSI: Container Storage Interface

CSI is a standard interface that allows storage vendors to integrate
their storage systems with Kubernetes.

A CSI driver can handle operations such as:

-   Provisioning a volume.
-   Attaching a volume to a node, where applicable.
-   Mounting a volume.
-   Unmounting and detaching a volume.
-   Expanding a volume, if supported.

Examples:

  Platform                 Common CSI driver
  ------------------------ -------------------------
  Azure Disk               `disk.csi.azure.com`
  Azure Files              `file.csi.azure.com`
  AWS EBS                  `ebs.csi.aws.com`
  AWS EFS                  `efs.csi.aws.com`
  Google Persistent Disk   `pd.csi.storage.gke.io`

## 17. StatefulSet and Persistent Storage

Stateful applications such as PostgreSQL, MySQL, and Kafka often need
stable storage identity.

A StatefulSet can define `volumeClaimTemplates` so that Kubernetes
creates a separate PVC for each Pod replica.

Conceptual example:

``` yaml
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: postgres
spec:
  serviceName: postgres
  replicas: 2
  selector:
    matchLabels:
      app: postgres
  template:
    metadata:
      labels:
        app: postgres
    spec:
      containers:
        - name: postgres
          image: postgres:16
          env:
            - name: POSTGRES_PASSWORD
              value: "change-me"
          volumeMounts:
            - name: postgres-data
              mountPath: /var/lib/postgresql/data
  volumeClaimTemplates:
    - metadata:
        name: postgres-data
      spec:
        accessModes:
          - ReadWriteOnce
        storageClassName: managed-csi-standard
        resources:
          requests:
            storage: 10Gi
```

With two replicas, Kubernetes creates separate claims for the replicas,
typically named similar to:

``` text
postgres-data-postgres-0
postgres-data-postgres-1
```

Each replica receives its own volume claim. **StatefulSet does not
automatically configure database replication.** Database replication,
backup, recovery, and consistency must be designed separately.

For a real PostgreSQL deployment, also configure appropriate credentials
through Secrets, health probes, resource requests/limits, backups, and a
supported database operating model. The YAML above is for illustrating
storage claims, not a production-ready database deployment.

## 18. Comparison of Common Volume Types

  -------------------------------------------------------------------------
  Type            Storage           Survives container         Survives Pod
                  location /                  restart?            deletion?
                  source                               
  --------------- --------------- -------------------- --------------------
  `emptyDir`      Node-local       Yes, while the same                   No
                  storage or                Pod exists 
                  memory                               

  `hostPath`      Worker node                      Yes    The host data may
                  filesystem                                 remain, but is
                                                              node-specific

  `configMap`     Kubernetes        Yes, while the Pod  ConfigMap object is
  volume          ConfigMap data         references it   independent of Pod

  `secret` volume Kubernetes        Yes, while the Pod     Secret object is
                  Secret data            references it   independent of Pod

  PVC-backed      Storage                 Normally yes        Normally yes,
  volume          represented by                         subject to reclaim
                  a PV                                   policy and backend
                                                                  behaviour

  Generic         PVC template      Depends on backing       Intended to be
  ephemeral       managed for a         volume and Pod removed with its Pod
  volume          Pod                        lifecycle 
  -------------------------------------------------------------------------

## 19. Common Troubleshooting Commands

``` bash
# List Pods
kubectl get pods -o wide

# View a Pod's volume definitions and mounts
kubectl describe pod <pod-name>

# List PersistentVolumes
kubectl get pv

# List PersistentVolumeClaims
kubectl get pvc

# List StorageClasses
kubectl get storageclass

# Inspect a PVC
kubectl describe pvc <pvc-name>

# Inspect a PV
kubectl describe pv <pv-name>

# View Pod events
kubectl get events --sort-by=.metadata.creationTimestamp
```

Common PVC states:

-   `Pending`: No suitable PV is bound yet, or dynamic
    provisioning/scheduling has not completed.
-   `Bound`: PVC is successfully bound to a PV.
-   `Lost`: The bound PV is no longer available.

For a `Pending` PVC, inspect its events and verify the StorageClass,
provisioner, requested capacity, access modes, topology, CSI driver, and
cloud permissions.

## 20. Best Practices

1.  Use `emptyDir` for temporary data, scratch space, and Pod-local
    sharing---not for data that must survive Pod deletion.
2.  Avoid `hostPath` for ordinary application data, especially in
    multi-node production clusters.
3.  Use PVCs for application data that must outlive individual Pods.
4.  Select a StorageClass that matches performance, availability,
    topology, and cost requirements.
5.  Understand reclaim policies before deleting PVCs.
6.  Use Secrets for sensitive values and apply appropriate encryption
    and RBAC controls.
7.  Configure backups and test restore procedures. Persistent storage is
    not a backup.
8.  Check access-mode support in the actual CSI driver and storage
    backend.
9.  For databases, use a suitable StatefulSet or database operator and
    design replication and recovery separately.
10. Monitor storage capacity, inode usage, I/O performance, and PVC
    status.

## 21. Interview Questions and Answers

### Q1. What is a Kubernetes Volume?

A Kubernetes Volume provides storage to containers in a Pod. Its
lifecycle and persistence depend on the volume type.

### Q2. What is the difference between `emptyDir` and `hostPath`?

`emptyDir` is created for a Pod and removed when the Pod is removed.
`hostPath` mounts a path from the worker node's filesystem and is tied
to that node's local data.

### Q3. Does `emptyDir` survive a container restart?

Yes. The data normally remains as long as the same Pod exists. It is
deleted when the Pod is removed.

### Q4. What is a PersistentVolume?

A PV is a cluster storage resource representing provisioned storage.

### Q5. What is a PersistentVolumeClaim?

A PVC is a request for storage. Kubernetes binds it to a suitable PV or
provisions storage dynamically through a StorageClass.

### Q6. What is a StorageClass?

A StorageClass defines a class of storage and the provisioner and
parameters used to create it. It enables dynamic provisioning.

### Q7. What is dynamic provisioning?

Dynamic provisioning automatically creates storage when a PVC requests a
suitable StorageClass, rather than requiring an administrator to
pre-create a PV.

### Q8. Does RWO mean only one Pod can use a volume?

No. RWO means read-write mounting from a single node. Multiple Pods on
that node may use it, depending on the driver and filesystem.

### Q9. What happens to a PV when its PVC is deleted?

The outcome depends on the reclaim policy. With `Retain`, the storage is
retained for manual handling. With `Delete`, the backing storage may be
deleted by the provisioner.

### Q10. Does StatefulSet automatically replicate database data?

No. StatefulSet provides stable Pod identity and can create separate
PVCs for replicas. Database replication must be configured separately.

## 22. Session Summary

Remember this storage flow:

``` text
Application Pod
      |
      v
     PVC
      |
      v
 StorageClass  (for dynamic provisioning)
      |
      v
 CSI Driver
      |
      v
 Storage Backend
      |
      v
     PV
```

For static provisioning, an administrator creates the PV first and the
PVC binds to it. For dynamic provisioning, the PVC references a
StorageClass and the provisioner creates the backing volume and PV.

**The key distinction:**

-   `emptyDir`: Temporary Pod-scoped storage.
-   `hostPath`: Node-local path mounted into a Pod.
-   `PV`: Cluster resource representing storage.
-   `PVC`: Application's storage request.
-   `StorageClass`: Defines how storage can be provisioned.
-   `CSI`: Standard integration between Kubernetes and storage systems.
