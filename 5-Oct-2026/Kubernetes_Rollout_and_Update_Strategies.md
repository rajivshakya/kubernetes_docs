# Kubernetes Rollout, Rolling Update & Update Strategies

## 1. Overview

Kubernetes uses different workload controllers to create and manage Pods.

The most important controllers for understanding application updates are:

- ReplicaSet
- Deployment
- StatefulSet
- DaemonSet

Each controller has different capabilities for updating Pods.

### Strategy Summary

| Controller | Supported Update Strategy | Rolling Update | Rollout History / Undo |
|---|---|---:|---:|
| ReplicaSet | No rollout strategy | ❌ | ❌ |
| Deployment | `RollingUpdate`, `Recreate` | ✅ | ✅ |
| StatefulSet | `RollingUpdate`, `OnDelete` | ✅ | ✅ |
| DaemonSet | `RollingUpdate`, `OnDelete` | ✅ | ✅ |

> **Important:** ReplicaSet is not a rollout controller. A Deployment uses ReplicaSets internally, but ReplicaSet itself does not provide rolling update, rollout history, or rollback functionality.

---

# 2. ReplicaSet

## 2.1 What is a ReplicaSet?

A ReplicaSet ensures that the desired number of Pod replicas are running.

For example:

```yaml
replicas: 3
```

means the ReplicaSet tries to keep three matching Pods running.

### Architecture

```text
ReplicaSet
    |
    +---- Pod 1
    +---- Pod 2
    +---- Pod 3
```

## 2.2 ReplicaSet Does NOT Support Rolling Update

A ReplicaSet does not have an update strategy such as:

```yaml
strategy:
  type: RollingUpdate
```

It also does not support:

```bash
kubectl rollout history rs <name>
kubectl rollout undo rs <name>
```

For example:

```bash
kubectl rollout history rs nginx-rs
```

will return an error similar to:

```text
error: no history viewer has been implemented for "ReplicaSet.apps"
```

## 2.3 ReplicaSet YAML

Create `replicaset.yaml`:

```yaml
apiVersion: apps/v1
kind: ReplicaSet
metadata:
  name: nginx-rs
  labels:
    app: nginx
spec:
  replicas: 3

  selector:
    matchLabels:
      app: nginx

  template:
    metadata:
      labels:
        app: nginx
    spec:
      containers:
        - name: nginx
          image: nginx:1.25
          ports:
            - containerPort: 80
```

Apply it:

```bash
kubectl apply -f replicaset.yaml
```

Check:

```bash
kubectl get rs
kubectl get pods
```

## 2.4 Demonstrate ReplicaSet Self-Healing

Delete one Pod:

```bash
kubectl delete pod <pod-name>
```

Watch the Pods:

```bash
kubectl get pods -w
```

The ReplicaSet will create a replacement Pod because its responsibility is to maintain the desired number of replicas.

### Key Point

> **ReplicaSet maintains the desired number of Pods, but it does not provide rollout or rollback functionality.**

---

# 3. Deployment

A Deployment is the most common Kubernetes controller for stateless applications.

The architecture is:

```text
Deployment
     |
     +---- ReplicaSet
              |
              +---- Pod
              +---- Pod
              +---- Pod
```

A Deployment manages ReplicaSets.

This is why ReplicaSets are commonly seen when working with Deployments.

---

# 4. Deployment Strategies

Deployment supports two update strategies:

1. `RollingUpdate`
2. `Recreate`

---

# 5. Deployment - Recreate Strategy

With `Recreate`, Kubernetes terminates the existing Pods before creating the new Pods.

### Flow

```text
Old Pods
   |
   | terminate
   v
No old Pods
   |
   | create
   v
New Pods
```

There can be temporary downtime during the update.

## 5.1 Recreate YAML

Create `deployment-recreate.yaml`:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nginx-deployment
  labels:
    app: nginx

spec:
  replicas: 3

  strategy:
    type: Recreate

  selector:
    matchLabels:
      app: nginx

  template:
    metadata:
      labels:
        app: nginx

    spec:
      containers:
        - name: nginx
          image: nginx:1.25
          ports:
            - containerPort: 80
```

Apply:

```bash
kubectl apply -f deployment-recreate.yaml
```

Check:

```bash
kubectl get deployment
kubectl get rs
kubectl get pods
```

## 5.2 Demonstrate Recreate

Change the image:

```bash
kubectl set image deployment/nginx-deployment nginx=nginx:1.27
```

Watch:

```bash
kubectl get pods -w
```

You will observe that the old Pods are terminated and then new Pods are created.

### Interview Explanation

> **In Recreate strategy, Kubernetes terminates all existing Pods before creating new Pods. This can cause temporary downtime.**

---

# 6. Deployment - RollingUpdate Strategy

`RollingUpdate` is the default Deployment strategy.

Instead of terminating all old Pods at once, Kubernetes gradually replaces old Pods with new Pods.

### Flow

```text
Old Pods
   |
   | gradually replaced
   v
New Pods
```

For example:

```text
Old Pod 1  -> New Pod 1
Old Pod 2  -> New Pod 2
Old Pod 3  -> New Pod 3
```

The application can remain available during the update, depending on the application's readiness and availability configuration.

## 6.1 RollingUpdate YAML

Create `deployment-rolling.yaml`:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nginx-deployment
  labels:
    app: nginx

spec:
  replicas: 3

  revisionHistoryLimit: 2

  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxUnavailable: 1
      maxSurge: 1

  selector:
    matchLabels:
      app: nginx

  template:
    metadata:
      labels:
        app: nginx

    spec:
      containers:
        - name: nginx
          image: nginx:1.25
          ports:
            - containerPort: 80
```

Apply:

```bash
kubectl apply -f deployment-rolling.yaml
```

Check:

```bash
kubectl get deployment
kubectl get rs
kubectl get pods
```

---

# 7. Understanding `maxUnavailable` and `maxSurge`

Consider:

```yaml
replicas: 3

rollingUpdate:
  maxUnavailable: 1
  maxSurge: 1
```

### `maxUnavailable: 1`

During the rollout, at most one desired Pod can be unavailable.

### `maxSurge: 1`

Kubernetes can temporarily create one additional Pod above the desired replica count.

Therefore, with three replicas, Kubernetes may temporarily have:

```text
Desired Pods = 3
Maximum Pods = 4
```

The exact sequence depends on Pod readiness and the controller's rollout logic.

---

# 8. Demonstrate Deployment Rolling Update

First check the current Pods:

```bash
kubectl get pods -o wide
```

Update the image:

```bash
kubectl set image deployment/nginx-deployment nginx=nginx:1.27
```

Check rollout status:

```bash
kubectl rollout status deployment/nginx-deployment
```

Watch Pods live:

```bash
kubectl get pods -w
```

Check ReplicaSets:

```bash
kubectl get rs
```

You should see a new ReplicaSet created for the new Pod template while the old ReplicaSet is scaled down.

---

# 9. Deployment Rollout History

Check rollout history:

```bash
kubectl rollout history deployment/nginx-deployment
```

View a particular revision:

```bash
kubectl rollout history deployment/nginx-deployment --revision=2
```

The Deployment maintains revision information using its managed ReplicaSets.

---

# 10. Deployment Rollback

Rollback to the previous revision:

```bash
kubectl rollout undo deployment/nginx-deployment
```

Check status:

```bash
kubectl rollout status deployment/nginx-deployment
```

Rollback to a specific revision:

```bash
kubectl rollout undo deployment/nginx-deployment --to-revision=1
```

Check history again:

```bash
kubectl rollout history deployment/nginx-deployment
```

---

# 11. `revisionHistoryLimit`

Deployment can control how many old ReplicaSets are retained.

Example:

```yaml
revisionHistoryLimit: 2
```

This means Kubernetes keeps two old revisions in addition to the current revision, subject to normal controller behavior and cleanup.

Example:

```text
Old Revision 1  -> may be deleted
Old Revision 2  -> retained
Current Revision 3 -> retained
```

> `revisionHistoryLimit` controls how many old ReplicaSets are retained for rollback/history. It is not an update strategy.

---

# 12. StatefulSet

StatefulSet is designed for stateful applications that require stable:

- Pod names
- Network identities
- Ordering
- Persistent storage associations

Example:

```text
nginx-sts-0
nginx-sts-1
nginx-sts-2
```

StatefulSet does **not** use ReplicaSets.

A simplified architecture is:

```text
StatefulSet
     |
     +---- Pod 0
     +---- Pod 1
     +---- Pod 2
```

For revision history, StatefulSet uses `ControllerRevision` objects.

---

# 13. StatefulSet Update Strategies

StatefulSet supports:

1. `RollingUpdate`
2. `OnDelete`

It does **not** support `Recreate`.

---

# 14. StatefulSet - RollingUpdate

Create `sts.yaml`:

```yaml
apiVersion: v1
kind: Service
metadata:
  name: nginx-headless
spec:
  clusterIP: None
  selector:
    app: nginx
  ports:
    - port: 80
      targetPort: 80

---
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: nginx-sts

spec:
  serviceName: nginx-headless
  replicas: 3

  revisionHistoryLimit: 2

  updateStrategy:
    type: RollingUpdate

  selector:
    matchLabels:
      app: nginx

  template:
    metadata:
      labels:
        app: nginx

    spec:
      containers:
        - name: nginx
          image: nginx:1.25
          ports:
            - containerPort: 80
```

Apply:

```bash
kubectl apply -f sts.yaml
```

Check:

```bash
kubectl get sts
kubectl get pods
```

Expected Pod names:

```text
nginx-sts-0
nginx-sts-1
nginx-sts-2
```

---

# 15. Demonstrate StatefulSet Rolling Update

Update the image:

```bash
kubectl set image statefulset/nginx-sts nginx=nginx:1.27
```

Watch:

```bash
kubectl get pods -w
```

Check rollout status:

```bash
kubectl rollout status statefulset/nginx-sts
```

Check history:

```bash
kubectl rollout history statefulset/nginx-sts
```

View a specific revision:

```bash
kubectl rollout history statefulset/nginx-sts --revision=2
```

StatefulSet performs an ordered rollout while preserving Pod identities.

For the default OrderedReady behavior, updates proceed from the highest ordinal toward the lowest ordinal, for example:

```text
nginx-sts-2
    |
nginx-sts-1
    |
nginx-sts-0
```

> The exact rollout timing depends on Pod readiness and StatefulSet configuration.

---

# 16. StatefulSet - OnDelete

With:

```yaml
updateStrategy:
  type: OnDelete
```

Kubernetes updates the StatefulSet's Pod template, but it does not automatically replace existing Pods.

Example:

```yaml
updateStrategy:
  type: OnDelete
```

Change the image:

```bash
kubectl set image statefulset/nginx-sts nginx=nginx:1.27
```

Existing Pods may continue running the old image.

To update a particular Pod, delete it manually:

```bash
kubectl delete pod nginx-sts-2
```

The StatefulSet controller recreates the Pod using the current Pod template.

Check:

```bash
kubectl get pods
```

### OnDelete Flow

```text
Update Pod Template
        |
        v
Existing Pod remains unchanged
        |
        v
Manually delete Pod
        |
        v
Controller recreates Pod
        |
        v
New Pod uses updated template
```

### Interview Explanation

> **In StatefulSet OnDelete strategy, existing Pods are not automatically updated when the Pod template changes. They are updated when the existing Pods are manually deleted and recreated by the StatefulSet controller.**

---

# 17. DaemonSet

DaemonSet ensures that a Pod runs on each eligible node according to its scheduling rules.

Example:

```text
Node 1 -> DaemonSet Pod
Node 2 -> DaemonSet Pod
Node 3 -> DaemonSet Pod
```

DaemonSet does **not** use ReplicaSets.

A simplified architecture is:

```text
DaemonSet
    |
    +---- Pod on Node 1
    +---- Pod on Node 2
    +---- Pod on Node 3
```

DaemonSet uses `ControllerRevision` objects for revision history.

---

# 18. DaemonSet Update Strategies

DaemonSet supports:

1. `RollingUpdate`
2. `OnDelete`

It does **not** support `Recreate`.

---

# 19. DaemonSet - RollingUpdate

Example `daemonset.yaml`:

```yaml
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: nginx-ds
  labels:
    app: nginx

spec:
  updateStrategy:
    type: RollingUpdate
    rollingUpdate:
      maxUnavailable: 1

  selector:
    matchLabels:
      app: nginx

  template:
    metadata:
      labels:
        app: nginx

    spec:
      containers:
        - name: nginx
          image: nginx:1.25
          ports:
            - containerPort: 80
```

Apply:

```bash
kubectl apply -f daemonset.yaml
```

Check:

```bash
kubectl get daemonset
kubectl get pods -o wide
```

---

# 20. Demonstrate DaemonSet Rolling Update

Update the image:

```bash
kubectl set image daemonset/nginx-ds nginx=nginx:1.27
```

Watch:

```bash
kubectl get pods -w
```

Check rollout:

```bash
kubectl rollout status daemonset/nginx-ds
```

Check history:

```bash
kubectl rollout history daemonset/nginx-ds
```

View a revision:

```bash
kubectl rollout history daemonset/nginx-ds --revision=2
```

Rollback:

```bash
kubectl rollout undo daemonset/nginx-ds
```

---

# 21. DaemonSet - OnDelete

Example:

```yaml
updateStrategy:
  type: OnDelete
```

Update the image:

```bash
kubectl set image daemonset/nginx-ds nginx=nginx:1.27
```

Existing Pods are not automatically replaced.

Delete a Pod manually:

```bash
kubectl delete pod <daemonset-pod-name>
```

The DaemonSet controller creates a replacement Pod using the updated Pod template.

### OnDelete Flow

```text
Update Pod Template
        |
        v
Existing DaemonSet Pods remain
        |
        v
Manually delete Pod
        |
        v
New Pod is created
        |
        v
New Pod uses updated template
```

---

# 22. Complete Strategy Comparison

## Deployment

```yaml
strategy:
  type: RollingUpdate
```

or:

```yaml
strategy:
  type: Recreate
```

### Deployment

```text
RollingUpdate  -> Automatic gradual update
Recreate       -> Delete old Pods, then create new Pods
```

---

## StatefulSet

```yaml
updateStrategy:
  type: RollingUpdate
```

or:

```yaml
updateStrategy:
  type: OnDelete
```

### StatefulSet

```text
RollingUpdate  -> Automatic ordered update
OnDelete       -> Update when Pods are manually deleted
```

---

## DaemonSet

```yaml
updateStrategy:
  type: RollingUpdate
```

or:

```yaml
updateStrategy:
  type: OnDelete
```

### DaemonSet

```text
RollingUpdate  -> Automatic gradual update
OnDelete       -> Update when Pods are manually deleted
```

---

## ReplicaSet

ReplicaSet has no rollout update strategy.

```text
ReplicaSet
    |
    +---- Maintains desired number of Pods
    |
    +---- Self-healing
    |
    +---- No rollout history
    |
    +---- No rollout undo
```

---

# 23. Final Interview Cheat Sheet

Remember this table:

| Controller | RollingUpdate | Recreate | OnDelete | Uses ReplicaSet |
|---|---:|---:|---:|---:|
| ReplicaSet | ❌ | ❌ | ❌ | N/A |
| Deployment | ✅ | ✅ | ❌ | ✅ |
| StatefulSet | ✅ | ❌ | ✅ | ❌ |
| DaemonSet | ✅ | ❌ | ✅ | ❌ |

### Most Important Points

1. **Deployment manages ReplicaSets.**
2. **ReplicaSet maintains the desired number of Pods but does not perform rollouts.**
3. **Deployment supports `RollingUpdate` and `Recreate`.**
4. **StatefulSet supports `RollingUpdate` and `OnDelete`.**
5. **DaemonSet supports `RollingUpdate` and `OnDelete`.**
6. **StatefulSet and DaemonSet do not use ReplicaSets.**
7. **StatefulSet and DaemonSet use ControllerRevision for revision history.**
8. **`OnDelete` means existing Pods are not automatically replaced after a template update.**
9. **`revisionHistoryLimit` controls retained old revisions; it is not a rollout strategy.**
10. **`maxUnavailable` and `maxSurge` are RollingUpdate parameters, not separate strategies.**

---

# 24. Common Rollout Commands

### Deployment

```bash
kubectl rollout status deployment/<name>
kubectl rollout history deployment/<name>
kubectl rollout history deployment/<name> --revision=2
kubectl rollout undo deployment/<name>
kubectl rollout undo deployment/<name> --to-revision=1
```

### StatefulSet

```bash
kubectl rollout status statefulset/<name>
kubectl rollout history statefulset/<name>
kubectl rollout history statefulset/<name> --revision=2
kubectl rollout undo statefulset/<name>
```

### DaemonSet

```bash
kubectl rollout status daemonset/<name>
kubectl rollout history daemonset/<name>
kubectl rollout history daemonset/<name> --revision=2
kubectl rollout undo daemonset/<name>
```

### ReplicaSet

```bash
kubectl rollout history rs/<name>
```

is **not supported**.

---

# 25. One-Line Interview Answer

> **Deployment supports RollingUpdate and Recreate; StatefulSet and DaemonSet support RollingUpdate and OnDelete; ReplicaSet does not support rollout strategies. Deployment uses ReplicaSets internally, while StatefulSet and DaemonSet maintain their own revision history using ControllerRevision objects.**
