# Kubernetes Controllers — Complete Session Notes

## 1. Session Objective

By the end of this session, participants should understand:

- Why Kubernetes needs controllers
- What problem controllers solve
- What the **desired state** and **actual state** mean
- How the Kubernetes **control loop / reconciliation loop** works
- The difference between a **Controller**, **Pod**, **ReplicaSet**, and **Deployment**
- The major Kubernetes workload controllers:
  - Deployment
  - ReplicaSet
  - DaemonSet
  - StatefulSet
  - Job
  - CronJob
- When to use each controller
- How controllers recover from failures
- How Deployment → ReplicaSet → Pod works
- Why we normally create Deployments instead of creating ReplicaSets directly
- How to choose the right controller for a real-world application

---

# 2. First Question: Why Do We Need Controllers?

Before discussing controllers, let's understand a basic Kubernetes problem.

Suppose we create one Pod:

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: nginx
spec:
  containers:
    - name: nginx
      image: nginx:latest
```

Kubernetes creates the Pod.

Now imagine the Pod crashes.

What happens?

If we created the Pod directly, Kubernetes does **not** automatically create another replacement Pod just because the Pod was supposed to exist.

This leads to the first important requirement:

> We need something that continuously watches the cluster and makes sure that the actual state matches the desired state.

That "something" is a **controller**.

---

# 3. The Core Kubernetes Concept: Desired State vs Actual State

Kubernetes is fundamentally based on the idea of **desired state**.

For example:

```text
Desired State:
I want 3 nginx Pods running.
```

The actual cluster may currently have:

```text
Actual State:
2 nginx Pods are running.
```

The controller detects the difference:

```text
Desired = 3
Actual  = 2
Difference = 1
```

The controller takes action:

```text
Create 1 additional Pod
```

Now:

```text
Desired = 3
Actual  = 3
```

The controller continues watching.

This is called **reconciliation**.

---

# 4. What Is a Kubernetes Controller?

A Kubernetes controller is a control-loop process that:

1. Watches Kubernetes resources
2. Determines the current/actual state
3. Compares it with the desired state
4. Takes corrective action
5. Continues watching for changes

In simple words:

> A controller continuously tries to make the actual state of the cluster match the desired state.

A simplified model is:

```text
              Desired State
                   |
                   v
        +----------------------+
        |     Controller       |
        |                      |
        | Observe              |
        | Compare              |
        | Reconcile            |
        +----------+-----------+
                   |
                   v
              Actual State
```

---

# 5. The Reconciliation Loop

The most important concept to explain in a controller session is the reconciliation loop.

```text
             +------------------+
             |  Desired State    |
             |  replicas: 3      |
             +---------+----------+
                       |
                       v
              +----------------+
              |  Controller    |
              +--------+-------+
                       |
                 Observe State
                       |
                       v
              +----------------+
              |  Actual State  |
              |  replicas: 2   |
              +--------+-------+
                       |
                Difference?
                       |
                      Yes
                       |
                       v
              Create 1 Pod
                       |
                       v
              Actual = 3
                       |
                       +-------> Watch again
```

The controller does not perform the action only once.

It keeps watching.

---

# 6. Why Is Continuous Reconciliation Important?

Imagine we have:

```text
Desired:
3 Pods
```

Initially:

```text
Actual:
3 Pods
```

Everything is fine.

Now one Pod crashes:

```text
Actual:
2 Pods
```

The controller notices:

```text
Desired = 3
Actual  = 2
```

It creates another Pod.

Then:

```text
Actual = 3
```

Now suppose someone manually deletes another Pod.

Again:

```text
Actual = 2
```

The controller creates another Pod.

This is why Kubernetes workloads are resilient.

The controller keeps bringing the environment back to the desired state.

---

# 7. What Problem Did Controllers Solve?

Before understanding controllers, imagine managing application instances manually.

For example:

```text
Application requires:
10 instances
```

An administrator would have to:

```text
Create Pod 1
Create Pod 2
Create Pod 3
...
Create Pod 10
```

If Pod 5 fails:

```text
Detect failure
Create replacement
```

If the application needs to scale from 10 → 20:

```text
Create 10 additional Pods
```

If the application needs to scale down:

```text
Delete 10 Pods
```

This becomes difficult and error-prone.

Controllers automate this.

---

# 8. What Controllers Give Us

Controllers provide:

- Self-healing
- Scaling
- Desired-state management
- Automatic replacement of failed Pods
- Rolling updates
- Rollbacks
- Node-level workload management
- Stable identity for stateful applications
- Batch job execution
- Scheduled jobs

So controllers are one of the major reasons Kubernetes can manage applications automatically.

---

# 9. Pod vs Controller

A very important distinction:

## Pod

A Pod is the smallest deployable unit in Kubernetes.

Example:

```text
Pod
 |
 +-- Container
```

A Pod does not provide the complete application lifecycle management that we normally need.

## Controller

A controller manages resources and continuously reconciles their state.

Example:

```text
Deployment
    |
    v
ReplicaSet
    |
    v
Pods
```

Therefore:

> Pod is the workload execution unit, while controllers manage the lifecycle of workloads.

---

# 10. Major Kubernetes Controllers

For application workload management, the major controllers are:

```text
Deployment
ReplicaSet
DaemonSet
StatefulSet
Job
CronJob
```

There are also many other controllers inside Kubernetes.

For example:

- Node Controller
- EndpointSlice Controller
- Namespace Controller
- ServiceAccount Controller
- Job Controller
- Deployment Controller
- StatefulSet Controller
- DaemonSet Controller
- ReplicaSet Controller
- PersistentVolume Controller
- CronJob Controller

The important point is:

> Kubernetes itself is built around many controllers working together.

---

# 11. Main Workload Controllers — Quick Comparison

| Controller | Main Purpose | Typical Use |
|---|---|---|
| Deployment | Manage stateless applications | Web/API applications |
| ReplicaSet | Maintain a fixed number of Pods | Usually managed by Deployment |
| DaemonSet | Run a Pod on every/all selected nodes | Agents, logging, monitoring |
| StatefulSet | Manage stateful applications with stable identity | Databases, Kafka, etc. |
| Job | Run a task until successful completion | Batch processing |
| CronJob | Run Jobs on a schedule | Backups, reports, cleanup |

---

# 12. ReplicaSet

## What Is a ReplicaSet?

A ReplicaSet ensures that a specified number of Pod replicas are running.

Example:

```yaml
apiVersion: apps/v1
kind: ReplicaSet
metadata:
  name: nginx-rs
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
```

The desired state is:

```text
3 Pods
```

If one Pod dies:

```text
Before:
Pod 1
Pod 2
Pod 3

Pod 2 crashes

After:
Pod 1
Pod 3
Pod 4
```

The ReplicaSet maintains the count.

---

# 13. What Does ReplicaSet Actually Do?

The ReplicaSet controller primarily answers:

> "How many Pods should exist?"

For example:

```yaml
replicas: 5
```

The ReplicaSet tries to maintain:

```text
5 matching Pods
```

It uses:

```yaml
selector:
  matchLabels:
    app: nginx
```

to identify the Pods it owns.

---

# 14. Why Don't We Usually Create ReplicaSets Directly?

Because ReplicaSet has limited application lifecycle functionality.

ReplicaSet can maintain:

```text
Desired number of Pods
```

But it does not provide the complete rollout management that Deployment provides.

For example:

- Rolling update
- Rollback
- Revision history
- Controlled application updates

Therefore, in normal application deployments:

```text
Deployment
    |
    v
ReplicaSet
    |
    v
Pods
```

We normally create a Deployment.

The Deployment creates and manages ReplicaSets.

---

# 15. Deployment

## What Is a Deployment?

Deployment is the most commonly used controller for **stateless applications**.

Typical examples:

- NGINX
- Java application
- Node.js API
- Python API
- Microservices
- REST APIs
- Frontend applications

A Deployment manages ReplicaSets, and ReplicaSets manage Pods.

Architecture:

```text
Deployment
     |
     v
ReplicaSet
     |
     +---- Pod
     +---- Pod
     +---- Pod
```

---

# 16. Deployment Example

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nginx-deployment
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

This tells Kubernetes:

> "I want three nginx Pods running."

---

# 17. Deployment and Self-Healing

Suppose:

```text
Deployment
replicas = 3
```

Actual:

```text
Pod 1
Pod 2
Pod 3
```

Now Pod 2 crashes.

The ReplicaSet notices:

```text
Desired = 3
Actual = 2
```

It creates:

```text
Pod 4
```

Final:

```text
Pod 1
Pod 3
Pod 4
```

So the Deployment ultimately provides self-healing through the ReplicaSet it manages.

---

# 18. Deployment and Scaling

Suppose we currently have:

```text
replicas: 3
```

We change it to:

```text
replicas: 5
```

The Deployment updates its ReplicaSet.

The ReplicaSet creates two additional Pods.

```text
Before:
Pod 1
Pod 2
Pod 3

After:
Pod 1
Pod 2
Pod 3
Pod 4
Pod 5
```

We can also use:

```bash
kubectl scale deployment nginx-deployment --replicas=5
```

---

# 19. Deployment and Rolling Updates

One of the most important features of Deployment is rolling update.

Suppose:

```text
Current version:
nginx:1.25
```

We want:

```text
nginx:1.26
```

We update:

```yaml
image: nginx:1.26
```

Deployment creates a new ReplicaSet.

```text
Deployment
     |
     +--------------------+
     |                    |
     v                    v
Old ReplicaSet       New ReplicaSet
nginx:1.25           nginx:1.26
     |                    |
   Pods                 Pods
```

Kubernetes gradually replaces the old Pods with new Pods.

This is called a:

> Rolling Update

---

# 20. Deployment Rollback

Suppose version 1.26 has a problem.

Deployment maintains revision history.

We can rollback:

```bash
kubectl rollout undo deployment nginx-deployment
```

Kubernetes can return to the previous ReplicaSet/version.

This is another reason to use Deployment instead of creating ReplicaSets directly.

---

# 21. Important Deployment Commands

Check Deployment:

```bash
kubectl get deployment
```

Detailed information:

```bash
kubectl describe deployment nginx-deployment
```

Check ReplicaSets:

```bash
kubectl get rs
```

Check Pods:

```bash
kubectl get pods
```

Check rollout:

```bash
kubectl rollout status deployment nginx-deployment
```

View history:

```bash
kubectl rollout history deployment nginx-deployment
```

Rollback:

```bash
kubectl rollout undo deployment nginx-deployment
```

---

# 22. When Should You Use Deployment?

Use Deployment when:

- Application is stateless
- Multiple interchangeable replicas are required
- Pods do not need stable identities
- Rolling updates are required
- Rollbacks are required
- Horizontal scaling is required

Examples:

```text
Frontend
REST API
Microservice
Web server
Stateless backend
```

---

# 23. DaemonSet

## What Is a DaemonSet?

DaemonSet ensures that a copy of a Pod runs on every node or every node matching a specified selection.

Think:

> "I want one Pod of this workload on each eligible node."

Example:

```text
Node 1 -> Agent Pod
Node 2 -> Agent Pod
Node 3 -> Agent Pod
Node 4 -> Agent Pod
```

If a new eligible node joins:

```text
Node 5 joins
       |
       v
DaemonSet creates Agent Pod
       |
       v
Node 5 -> Agent Pod
```

---

# 24. Why Do We Need DaemonSet?

Suppose you install a log collection agent.

You want:

```text
Every Kubernetes node
       |
       v
Log Agent
```

If you use Deployment:

```text
Deployment
replicas = 3
```

the scheduler may place the three Pods on only three nodes.

That does not guarantee one agent per node.

DaemonSet solves this.

---

# 25. Typical DaemonSet Use Cases

DaemonSet is commonly used for node-level agents such as:

### Logging

Examples:

```text
Fluent Bit
Fluentd
Filebeat
```

### Monitoring

Examples:

```text
Node Exporter
Monitoring agents
```

### Security

Examples:

```text
Security/endpoint agents
Runtime security agents
```

### Networking

Some networking components are deployed using DaemonSets.

Examples can include:

```text
CNI-related node agents
kube-proxy
```

The exact implementation depends on the Kubernetes distribution and networking stack.

---

# 26. DaemonSet Example

```yaml
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: nginx-daemon
spec:
  selector:
    matchLabels:
      app: nginx-daemon

  template:
    metadata:
      labels:
        app: nginx-daemon

    spec:
      containers:
        - name: nginx
          image: nginx:1.25
```

If there are three eligible nodes:

```text
Node 1 -> Pod
Node 2 -> Pod
Node 3 -> Pod
```

---

# 27. DaemonSet and Node Addition

This is an important interview/session example.

Suppose:

```text
Existing nodes:
Node 1
Node 2
Node 3
```

DaemonSet creates:

```text
Agent Pod on Node 1
Agent Pod on Node 2
Agent Pod on Node 3
```

Now a new node joins:

```text
Node 4
```

DaemonSet automatically creates:

```text
Agent Pod on Node 4
```

Therefore:

> DaemonSet follows the node population rather than maintaining a fixed total replica count.

---

# 28. DaemonSet vs Deployment

| Feature | Deployment | DaemonSet |
|---|---|---|
| Main goal | Run application replicas | Run Pod on each eligible node |
| Replica concept | Fixed desired replicas | One per eligible node |
| Typical use | Web/API | Node agent |
| Node distribution | Scheduler decides | Node coverage is the goal |
| New node | No automatic extra Pod unless replica count changes | Pod automatically added |
| Example | NGINX API | Fluent Bit |

---

# 29. StatefulSet

## Why Do We Need StatefulSet?

Deployment is excellent for stateless applications.

But some applications require:

- Stable network identity
- Stable Pod names
- Persistent storage
- Ordered startup
- Ordered termination
- Ordered updates
- Stable association between a Pod and its storage

Examples:

```text
Database
Kafka
ZooKeeper
Elasticsearch
Some clustered applications
```

These workloads are often described as **stateful**.

---

# 30. What Does "Stateful" Mean?

Consider three Pods:

```text
Pod A
Pod B
Pod C
```

For a stateless application, any Pod can usually serve any request.

If Pod A dies:

```text
Pod A -> replaced by another interchangeable Pod
```

The identity is not important.

But for a stateful application, identity may matter.

For example:

```text
database-0
database-1
database-2
```

Each instance may have a specific identity and storage association.

---

# 31. StatefulSet Stable Identity

StatefulSet creates predictable names.

For:

```yaml
replicas: 3
```

we may get:

```text
mysql-0
mysql-1
mysql-2
```

If `mysql-1` is recreated, Kubernetes can recreate the Pod with the same ordinal identity:

```text
mysql-1
```

This is different from the random-looking names typically seen with ReplicaSet/Deployment-managed Pods.

---

# 32. StatefulSet and Persistent Storage

StatefulSet can work with `volumeClaimTemplates`.

Conceptually:

```text
mysql-0
   |
   +--> PVC mysql-data-mysql-0

mysql-1
   |
   +--> PVC mysql-data-mysql-1

mysql-2
   |
   +--> PVC mysql-data-mysql-2
```

This provides a stable relationship between:

```text
Pod identity
       |
       v
Persistent storage
```

---

# 33. StatefulSet Example

```yaml
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: web
spec:
  serviceName: web
  replicas: 3

  selector:
    matchLabels:
      app: web

  template:
    metadata:
      labels:
        app: web

    spec:
      containers:
        - name: nginx
          image: nginx:1.25

          volumeMounts:
            - name: data
              mountPath: /usr/share/nginx/html

  volumeClaimTemplates:
    - metadata:
        name: data
      spec:
        accessModes:
          - ReadWriteOnce

        resources:
          requests:
            storage: 5Gi
```

This is only an example of StatefulSet mechanics. A production database needs additional considerations such as replication, backups, storage performance, failure handling, and application-level clustering.

---

# 34. StatefulSet Ordered Behavior

Depending on configuration, StatefulSet can create Pods in an ordered manner.

For example:

```text
Create:
web-0
   |
   v
web-1
   |
   v
web-2
```

And during scale-down:

```text
web-2
   |
   v
web-1
   |
   v
web-0
```

The exact behavior is controlled by StatefulSet policies such as:

```yaml
podManagementPolicy
```

and update strategy.

---

# 35. StatefulSet vs Deployment

| Feature | Deployment | StatefulSet |
|---|---|---|
| Primary use | Stateless workloads | Stateful workloads |
| Pod identity | Not stable | Stable |
| Pod names | Generated names | Predictable ordinal names |
| Storage identity | Not inherently tied to Pod identity | Can maintain stable storage association |
| Ordering | Generally not identity-oriented | Supports ordered behavior |
| Example | REST API | Database cluster |

---

# 36. Important Warning: StatefulSet Does Not Make an Application Stateful

This is a very important interview point.

Simply using:

```text
StatefulSet
```

does not automatically make an application highly available or distributed.

The application itself must support the required state-management/replication model.

For example:

```text
StatefulSet
    +
Persistent Storage
    +
Application-level replication
    +
Backup/Recovery
```

may be required for a production database.

---

# 37. Job

## What Is a Job?

A Job is used for a task that should:

> Run to completion successfully.

Unlike a Deployment, which is designed for continuously running workloads, a Job is designed for finite work.

Examples:

- Database migration
- Batch processing
- Data transformation
- One-time administrative task
- Report generation
- Image processing

---

# 38. Deployment vs Job

Deployment:

```text
Start application
     |
     v
Keep running
     |
     v
If Pod dies -> replace it
```

Job:

```text
Start task
     |
     v
Run task
     |
     v
Complete successfully
     |
     v
Job complete
```

So:

```text
Deployment = long-running workload
Job        = finite workload
```

---

# 39. Job Example

```yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: hello-job
spec:
  template:
    spec:
      restartPolicy: Never

      containers:
        - name: hello
          image: busybox:1.36
          command:
            - /bin/sh
            - -c
            - echo "Hello from Kubernetes Job"
```

The Pod runs the command.

After successful completion:

```text
Job = Complete
```

---

# 40. Job Failure and Retry

Suppose the task fails.

A Job can retry according to its configuration.

For example:

```yaml
backoffLimit: 4
```

This controls how many retries are allowed before the Job is considered failed.

---

# 41. Job Parallelism

Jobs can also process work in parallel.

Important fields include:

```yaml
completions:
parallelism:
```

Example concept:

```text
completions: 10
parallelism: 3
```

Meaning:

```text
Need 10 successful completions
Run up to 3 Pods at a time
```

This is useful for batch workloads.

---

# 42. CronJob

## What Is a CronJob?

CronJob creates Jobs according to a schedule.

Think:

```text
Linux cron
       +
Kubernetes Job
```

Example requirements:

```text
Run database backup every day at 2 AM
```

CronJob can be used.

---

# 43. CronJob Example

```yaml
apiVersion: batch/v1
kind: CronJob
metadata:
  name: backup-job
spec:
  schedule: "0 2 * * *"

  jobTemplate:
    spec:
      template:
        spec:
          restartPolicy: Never

          containers:
            - name: backup
              image: busybox:1.36
              command:
                - /bin/sh
                - -c
                - echo "Running backup"
```

Schedule:

```text
0 2 * * *
```

means:

```text
Every day at 2:00 AM
```

---

# 44. CronJob Architecture

```text
CronJob
   |
   | creates according to schedule
   v
Job
   |
   v
Pod
   |
   v
Container
```

Important:

> CronJob does not directly manage the application Pod as a continuously running workload. It creates Jobs, and Jobs create Pods.

---

# 45. Controller Hierarchy

A very useful way to explain Kubernetes workload controllers is:

```text
Deployment
    |
    v
ReplicaSet
    |
    v
Pod
    |
    v
Container
```

For scheduled batch workloads:

```text
CronJob
    |
    v
Job
    |
    v
Pod
```

For node-level workloads:

```text
DaemonSet
    |
    v
Pods
```

For stateful workloads:

```text
StatefulSet
    |
    v
Pods
    |
    +--> PersistentVolumeClaims
```

---

# 46. Important Clarification: Controllers Are Not All Hierarchical

Do not teach this as if there is one universal hierarchy.

For example:

```text
Deployment -> ReplicaSet -> Pod
```

is a specific management relationship.

But:

```text
DaemonSet -> Pod
StatefulSet -> Pod
Job -> Pod
CronJob -> Job -> Pod
```

are different relationships.

The common idea is:

> Each controller owns/manages resources and reconciles them toward its desired state.

---

# 47. How Kubernetes Knows Which Pods Belong to Which Controller

Labels and selectors are very important.

Example:

```yaml
labels:
  app: nginx
```

Controller:

```yaml
selector:
  matchLabels:
    app: nginx
```

The controller uses the selector to identify the resources it manages.

Conceptually:

```text
Controller
     |
     | selector: app=nginx
     |
     v
Pods with app=nginx
```

---

# 48. OwnerReferences

Kubernetes also uses `ownerReferences` to represent ownership relationships.

For example:

```text
Deployment
     |
     v
ReplicaSet
     |
     v
Pod
```

These ownership relationships help Kubernetes understand which object is responsible for another object.

This is important for lifecycle management and garbage collection.

---

# 49. What Happens When a Pod Is Deleted?

Consider:

```text
Deployment
replicas = 3
```

Pods:

```text
Pod A
Pod B
Pod C
```

Someone runs:

```bash
kubectl delete pod Pod-B
```

What happens?

```text
Pod-B deleted
      |
      v
ReplicaSet observes:
Actual = 2
Desired = 3
      |
      v
ReplicaSet creates replacement Pod
```

The user does not need to manually recreate it.

This is reconciliation.

---

# 50. What Happens If a Node Fails?

Suppose:

```text
Node 1
Node 2
Node 3
```

Deployment has:

```text
3 replicas
```

If Node 2 fails:

```text
Node 1 -> Pod A
Node 2 -> Pod B  X
Node 3 -> Pod C
```

Kubernetes detects the failure.

The workload controller/scheduler machinery works together to restore the desired workload, subject to cluster capacity, scheduling constraints, storage behavior, and readiness.

For a stateless Deployment, a replacement Pod can be scheduled onto an available node.

Conceptually:

```text
Node 2 fails
     |
     v
Pod B unavailable
     |
     v
Controller detects desired != actual
     |
     v
Replacement Pod requested
     |
     v
Scheduler selects an eligible node
     |
     v
Replacement Pod starts
```

---

# 51. Controller vs Scheduler

This is a common interview question.

## Controller

The controller decides:

> "I need another Pod."

## Scheduler

The scheduler decides:

> "Which node should this Pod run on?"

So:

```text
Controller
    |
    | Need a Pod
    v
Pod created / pending
    |
    v
Scheduler
    |
    | Selects node
    v
Node
    |
    v
Pod runs
```

The controller and scheduler have different responsibilities.

---

# 52. Controller vs kubelet

Another common question.

### Controller

Works at the cluster control-plane level and manages desired state.

### kubelet

Runs on a node and is responsible for making sure the Pods assigned to that node are running as specified.

Conceptually:

```text
Controller
   |
   v
Desired workload
   |
   v
Scheduler
   |
   v
Node
   |
   v
kubelet
   |
   v
Containers
```

---

# 53. What Does "Self-Healing" Actually Mean?

Self-healing does not mean Kubernetes can fix every possible application problem.

It means Kubernetes controllers can detect certain differences between desired and observed state and take corrective actions.

For example:

```text
Pod deleted
    |
    v
Replacement created
```

But if the application itself has a bug:

```text
Application starts
      |
      v
Application crashes
      |
      v
Pod restarts/recreated
      |
      v
Application crashes again
```

Kubernetes may keep restarting/replacing it, but it cannot automatically fix the application bug.

---

# 54. Deployment vs ReplicaSet vs Pod — The Simple Explanation

Use this analogy in your session:

### Pod

> "Run this application container."

### ReplicaSet

> "Make sure I have N copies of this Pod."

### Deployment

> "Manage the lifecycle of my application, including replicas, rolling updates, and rollbacks."

This is a very easy way for beginners to remember the relationship.

---

# 55. How to Decide Which Controller to Use

Use this decision tree.

```text
                 What type of workload?
                          |
            +-------------+-------------+
            |                           |
       Long-running                 Finite task
            |                           |
            |                     +-----+-----+
            |                     |           |
            |                  One-time     Scheduled
            |                     |           |
            |                    Job       CronJob
            |
      +-----+----------------+
      |                      |
   Stateless              Stateful
      |                      |
 Deployment              StatefulSet
      |
      |
Need one Pod on
each eligible node?
      |
     Yes
      |
  DaemonSet
```

Important: DaemonSet is selected based on the node-coverage requirement, so it can apply to node agents whether the underlying application is otherwise thought of as stateless or stateful.

---

# 56. Controller Selection — Practical Examples

## Example 1: Online Shopping Website

Requirement:

```text
10 frontend Pods
```

Characteristics:

- Stateless
- Scalable
- Rolling updates required

Use:

```text
Deployment
```

---

## Example 2: REST API

Requirement:

```text
5 API replicas
```

Use:

```text
Deployment
```

---

## Example 3: Log Collector

Requirement:

```text
One log agent on every node
```

Use:

```text
DaemonSet
```

---

## Example 4: Node Monitoring Agent

Requirement:

```text
Monitoring agent on every node
```

Use:

```text
DaemonSet
```

---

## Example 5: Database Cluster

Requirement:

```text
Stable identity
Stable storage
Ordered operations
```

Potential choice:

```text
StatefulSet
```

But production database architecture must also consider the database's own clustering/replication mechanism, backup, recovery, storage, and operational requirements.

---

## Example 6: Database Migration

Requirement:

```text
Run migration once
Exit after success
```

Use:

```text
Job
```

---

## Example 7: Daily Backup

Requirement:

```text
Run backup every day at 2 AM
```

Use:

```text
CronJob
```

---

# 57. Deployment vs StatefulSet — The Key Question

Ask:

> "Does each replica need its own stable identity and/or stable storage association?"

If the answer is generally:

```text
No
```

Use:

```text
Deployment
```

If the workload requires:

```text
Stable identity
Stable storage association
Ordered behavior
```

consider:

```text
StatefulSet
```

But do not choose StatefulSet simply because an application writes data.

A stateful application may also be better operated outside Kubernetes, depending on the architecture.

---

# 58. Deployment vs DaemonSet — The Key Question

Ask:

> "Do I need a fixed number of application replicas, or do I need one Pod per eligible node?"

If:

```text
Fixed number of replicas
```

use:

```text
Deployment
```

If:

```text
One Pod on every eligible node
```

use:

```text
DaemonSet
```

---

# 59. Job vs Deployment — The Key Question

Ask:

> "Should this workload continue running, or should it finish?"

If:

```text
Continue running
```

use:

```text
Deployment
```

If:

```text
Run -> Complete -> Stop
```

use:

```text
Job
```

---

# 60. Job vs CronJob

Ask:

> "Should this task run once, or repeatedly according to a schedule?"

Once:

```text
Job
```

Repeated schedule:

```text
CronJob
```

---

# 61. Why Not Use Deployment for Everything?

Because each controller expresses a different operational requirement.

Deployment is optimized for:

```text
Long-running stateless applications
```

DaemonSet is optimized for:

```text
Node-level coverage
```

StatefulSet is optimized for:

```text
Stable identity/storage semantics
```

Job is optimized for:

```text
Finite work
```

CronJob is optimized for:

```text
Scheduled finite work
```

Using the wrong controller can make workload behavior harder to manage.

---

# 62. Real-World Kubernetes Architecture

A typical microservices application might look like:

```text
                    Kubernetes Cluster
                           |
             +-------------+-------------+
             |                           |
             v                           v
       Deployment                    Deployment
       Frontend                      Backend API
             |                           |
          Pods                         Pods
             |                           |
             +-------------+-------------+
                           |
                           v
                       Service
                           |
                           v
                      Application
```

Node-level components:

```text
Node 1 -> DaemonSet Pod
Node 2 -> DaemonSet Pod
Node 3 -> DaemonSet Pod
```

Database:

```text
StatefulSet
    |
    +-- DB-0 -> Storage
    +-- DB-1 -> Storage
    +-- DB-2 -> Storage
```

Scheduled backup:

```text
CronJob
   |
   v
Job
   |
   v
Pod
```

---

# 63. Kubernetes Controllers and API Server

A useful architectural explanation:

```text
kubectl
   |
   v
API Server
   |
   v
Kubernetes API Objects
   |
   +------------------+
   |                  |
   v                  v
Controllers       Scheduler
   |                  |
   v                  |
Desired workload      |
   |                  |
   +--------+---------+
            |
            v
          Nodes
            |
            v
          kubelet
```

The API server is the central interface through which Kubernetes components communicate about cluster state.

Controllers watch resources through the Kubernetes API and perform actions through the API.

---

# 64. Controllers Are Event-Driven + Reconciliation-Based

A controller can react to changes such as:

- New object created
- Object updated
- Pod deleted
- Node status changed
- Replica count changed
- Image changed
- Configuration changed

But the deeper principle is not simply:

```text
Event -> Action
```

It is:

```text
Observe current state
        +
Desired state
        |
        v
Reconcile
```

This makes Kubernetes robust even when changes happen outside the controller's immediate action.

---

# 65. Important Interview Question: Is Controller a Single Process?

No.

"Kubernetes controller" is a general concept.

There are many controllers.

They can run as components of the Kubernetes control plane or as controllers/operators running in the cluster.

A simplified view:

```text
kube-controller-manager
        |
        +-- Node Controller
        +-- Job Controller
        +-- ServiceAccount Controller
        +-- Namespace Controller
        +-- ReplicaSet Controller
        +-- etc.
```

Some controllers are implemented outside the core control plane.

For example:

```text
Ingress Controller
Cloud Controller
Operator
Custom Controller
```

---

# 66. What Is an Operator?

An Operator is essentially a Kubernetes controller pattern used to automate operational knowledge for a specific application or domain.

For example, an operator can manage:

```text
Database cluster
Backup
Upgrade
Failover
Configuration
Scaling
```

An Operator commonly uses:

```text
Custom Resource Definition (CRD)
+
Controller
```

Conceptually:

```text
Custom Resource
      |
      v
Operator / Controller
      |
      v
Kubernetes resources
```

---

# 67. Built-in Controller vs Custom Controller

### Built-in controllers

Examples:

```text
Deployment Controller
ReplicaSet Controller
DaemonSet Controller
StatefulSet Controller
Job Controller
CronJob Controller
```

### Custom controllers

Built for custom application/platform behavior.

Often implemented using:

```text
Operator SDK
Kubebuilder
controller-runtime
```

---

# 68. A Simple Mental Model for Controllers

Remember this formula:

```text
Desired State
      -
Actual State
      =
Difference
```

Then:

```text
Controller
    |
    v
Removes the difference
```

Then:

```text
Observe again
```

So:

```text
Observe
   ↓
Compare
   ↓
Act
   ↓
Observe
   ↓
Compare
   ↓
Act
   ↓
...
```

This is the Kubernetes reconciliation loop.

---

# 69. Recommended Teaching Sequence

For a live session, teach controllers in this order:

### Part 1 — Problem

Start with:

> "What happens if I create a Pod and the Pod dies?"

Then explain why manually managing Pods is difficult.

### Part 2 — Desired State

Explain:

```text
Desired state vs Actual state
```

### Part 3 — Reconciliation

Explain:

```text
Observe → Compare → Act → Observe
```

### Part 4 — ReplicaSet

Ask:

> "What if I want 3 Pods instead of 1?"

Introduce ReplicaSet.

### Part 5 — Deployment

Ask:

> "What if I want rolling updates and rollback?"

Introduce Deployment.

### Part 6 — DaemonSet

Ask:

> "What if I want one Pod on every node?"

Introduce DaemonSet.

### Part 7 — StatefulSet

Ask:

> "What if every Pod needs stable identity and storage?"

Introduce StatefulSet.

### Part 8 — Job

Ask:

> "What if the task should finish?"

Introduce Job.

### Part 9 — CronJob

Ask:

> "What if the task should run on a schedule?"

Introduce CronJob.

---

# 70. Live Demo Flow

A good practical demo can be built around one Deployment.

## Step 1 — Create Deployment

```bash
kubectl create deployment nginx --image=nginx
```

Check:

```bash
kubectl get deployment
kubectl get rs
kubectl get pods
```

Explain:

```text
Deployment
   ↓
ReplicaSet
   ↓
Pod
```

---

## Step 2 — Scale

```bash
kubectl scale deployment nginx --replicas=3
```

Check:

```bash
kubectl get pods
```

Explain:

```text
Desired = 3
Actual = 3
```

---

## Step 3 — Delete a Pod

```bash
kubectl delete pod <pod-name>
```

Immediately check:

```bash
kubectl get pods
```

Explain:

```text
Pod deleted
   ↓
ReplicaSet detects desired != actual
   ↓
Replacement Pod created
```

This is one of the best demonstrations of reconciliation.

---

# 71. Live Demo — Rolling Update

Check current image:

```bash
kubectl get deployment nginx -o wide
```

Update image:

```bash
kubectl set image deployment/nginx nginx=nginx:1.26
```

Check rollout:

```bash
kubectl rollout status deployment/nginx
```

Watch Pods:

```bash
kubectl get pods -w
```

Then show:

```bash
kubectl get rs
```

Explain that the Deployment creates a new ReplicaSet and gradually replaces Pods.

---

# 72. Live Demo — Rollback

Check history:

```bash
kubectl rollout history deployment/nginx
```

Rollback:

```bash
kubectl rollout undo deployment/nginx
```

Check:

```bash
kubectl rollout status deployment/nginx
```

This demonstrates why Deployment is more powerful than directly using ReplicaSet.

---

# 73. Live Demo — DaemonSet

Create a simple DaemonSet YAML.

Then:

```bash
kubectl apply -f daemonset.yaml
```

Check:

```bash
kubectl get daemonset
kubectl get pods -o wide
```

Show that Pods are distributed according to the DaemonSet's node-selection rules.

Then add a node if your lab environment supports it and show that the DaemonSet creates a Pod for the new eligible node.

---

# 74. Live Demo — Job

Create:

```bash
kubectl apply -f job.yaml
```

Check:

```bash
kubectl get jobs
kubectl get pods
```

Then:

```bash
kubectl logs <job-pod>
```

Explain:

```text
Job
 ↓
Pod
 ↓
Task
 ↓
Completed
```

---

# 75. Live Demo — CronJob

Create:

```bash
kubectl apply -f cronjob.yaml
```

Check:

```bash
kubectl get cronjobs
```

Then:

```bash
kubectl get jobs
```

And:

```bash
kubectl get pods
```

Explain:

```text
CronJob
   |
   | schedule
   v
Job
   |
   v
Pod
```

For a quick lab demonstration, use a frequent schedule such as every minute, then change it back to the intended production schedule.

---

# 76. Useful kubectl Commands for Controller Troubleshooting

### Deployment

```bash
kubectl get deploy
kubectl describe deploy <name>
kubectl rollout status deploy <name>
kubectl rollout history deploy <name>
kubectl rollout undo deploy <name>
```

### ReplicaSet

```bash
kubectl get rs
kubectl describe rs <name>
```

### DaemonSet

```bash
kubectl get ds
kubectl describe ds <name>
```

### StatefulSet

```bash
kubectl get sts
kubectl describe sts <name>
```

### Job

```bash
kubectl get jobs
kubectl describe job <name>
```

### CronJob

```bash
kubectl get cronjobs
kubectl describe cronjob <name>
```

---

# 77. Troubleshooting Controller Problems

When a workload is not behaving correctly, follow this approach.

## Step 1 — Check the Controller

```bash
kubectl get deployment
```

or:

```bash
kubectl get daemonset
kubectl get statefulset
kubectl get job
kubectl get cronjob
```

## Step 2 — Describe It

```bash
kubectl describe deployment <name>
```

Look at:

- Events
- Desired replicas
- Available replicas
- Conditions
- Selector
- Pod template

## Step 3 — Check ReplicaSets

For Deployment:

```bash
kubectl get rs
```

## Step 4 — Check Pods

```bash
kubectl get pods -o wide
```

## Step 5 — Describe Pod

```bash
kubectl describe pod <pod-name>
```

## Step 6 — Check Logs

```bash
kubectl logs <pod-name>
```

For previous crashed container:

```bash
kubectl logs <pod-name> --previous
```

---

# 78. Common Controller Problems

## Problem 1 — Deployment Has Unavailable Pods

Possible reasons:

- ImagePullBackOff
- CrashLoopBackOff
- Insufficient resources
- Readiness probe failure
- Scheduling constraints
- Taints/tolerations
- Node failure
- PVC problems
- Network/configuration problems

The controller can create Pods, but the Pods still need to become healthy.

---

## Problem 2 — DaemonSet Doesn't Run on a Node

Check:

- Node selectors
- Affinity
- Taints
- Tolerations
- Resource availability
- Pod security/admission restrictions

Remember:

> DaemonSet means every **eligible** node, not necessarily every physical node regardless of constraints.

---

## Problem 3 — StatefulSet Pod Is Pending

Check:

- PVC
- StorageClass
- Volume provisioning
- Node constraints
- Resources
- Affinity
- Taints/tolerations

---

## Problem 4 — Job Never Completes

Check:

- Container command
- Application exit status
- Logs
- Restart policy
- Resource availability
- `backoffLimit`
- Job conditions

---

# 79. Common Interview Questions

## Q1. Why do we need controllers?

**Answer:**

Controllers continuously monitor the cluster and reconcile the actual state with the desired state. They provide automation such as self-healing, scaling, rolling updates, scheduled execution, node-level workload placement, and stateful workload management.

---

## Q2. What is reconciliation?

**Answer:**

Reconciliation is the process of comparing the desired state with the current observed state and taking corrective action whenever they differ.

---

## Q3. What is the difference between Pod and Deployment?

**Answer:**

A Pod is the smallest deployable workload unit, while a Deployment manages a set of replicated Pods through ReplicaSets and provides features such as rolling updates, scaling, and rollback.

---

## Q4. What is the relationship between Deployment and ReplicaSet?

**Answer:**

A Deployment manages ReplicaSets. The ReplicaSet maintains the desired number of Pods. During an update, the Deployment creates a new ReplicaSet and gradually moves the workload from the old ReplicaSet to the new one.

---

## Q5. Why use Deployment instead of ReplicaSet directly?

**Answer:**

Deployment provides higher-level application lifecycle management such as rolling updates, rollback, revision history, and controlled changes. ReplicaSet mainly maintains the desired number of matching Pods.

---

## Q6. What is DaemonSet?

**Answer:**

DaemonSet ensures that a Pod runs on every node, or every node matching its scheduling criteria. It is commonly used for node-level agents such as logging, monitoring, networking, and security agents.

---

## Q7. What is StatefulSet?

**Answer:**

StatefulSet manages workloads that require stable network identity, stable Pod identity, persistent storage association, and/or ordered lifecycle behavior.

---

## Q8. Does StatefulSet automatically make a database highly available?

**Answer:**

No. StatefulSet provides Kubernetes-level identity, storage, and lifecycle semantics. High availability and data consistency still depend on the database/application's own replication and recovery architecture.

---

## Q9. Difference between Job and Deployment?

**Answer:**

Deployment is intended for long-running workloads, while Job is intended for finite work that should eventually complete successfully.

---

## Q10. Difference between Job and CronJob?

**Answer:**

A Job executes a finite task. A CronJob creates Jobs according to a schedule.

---

## Q11. What happens when a Pod managed by a Deployment is deleted?

**Answer:**

The ReplicaSet associated with the Deployment observes that the actual number of Pods is below the desired number and creates a replacement Pod.

---

## Q12. What happens when a node fails?

**Answer:**

Kubernetes detects node failure and the relevant controllers work with the scheduler and other control-plane components to restore the desired workload where possible, subject to scheduling, capacity, storage, and application constraints.

---

## Q13. Does a controller create the Pod directly on a node?

**Answer:**

The controller creates or manages the Pod API object. The scheduler determines an appropriate node for an unscheduled Pod, and the kubelet on that node works with the container runtime to run the containers.

---

## Q14. Can we use Deployment for a database?

**Answer:**

It is generally not appropriate when the database instances require stable identity and storage semantics. StatefulSet may be appropriate, but the database's own architecture and operational requirements must also be considered.

---

# 80. Important Concept: Controller Does Not Mean "Container Manager"

A controller does not directly run containers.

The responsibilities are distributed.

Simplified flow:

```text
Controller
   |
   | Desired workload
   v
API Server
   |
   v
Pod object
   |
   v
Scheduler
   |
   v
Node
   |
   v
kubelet
   |
   v
Container Runtime
   |
   v
Container
```

This distinction is important for interviews.

---

# 81. A Very Simple Real-Life Analogy

You can use this analogy during the session.

Imagine a restaurant manager.

Desired state:

```text
Restaurant needs 5 waiters.
```

Actual state:

```text
Only 4 waiters are available.
```

Manager notices the difference:

```text
Desired = 5
Actual  = 4
```

Manager takes action:

```text
Call one additional waiter.
```

Now:

```text
Desired = 5
Actual  = 5
```

The manager keeps monitoring.

This is similar to reconciliation.

### Mapping

```text
Restaurant Manager -> Controller
Required staff     -> Desired state
Current staff      -> Actual state
Hiring/replacing   -> Reconciliation action
```

---

# 82. One-Line Memory Trick

Remember these six lines:

```text
Deployment  -> Stateless application
ReplicaSet  -> Maintain replica count
DaemonSet   -> One Pod per eligible node
StatefulSet -> Stable identity/storage
Job         -> Run to completion
CronJob     -> Run Jobs on a schedule
```

This is enough to recall the basic purpose of each controller in an interview.

---

# 83. Final Controller Decision Table

| Requirement | Controller |
|---|---|
| Run 3 replicas of a stateless API | Deployment |
| Rolling update required | Deployment |
| Rollback required | Deployment |
| Maintain N matching Pods | ReplicaSet |
| One logging agent per node | DaemonSet |
| One monitoring agent per node | DaemonSet |
| Stable Pod identity | StatefulSet |
| Stable storage association | StatefulSet |
| Ordered stateful lifecycle | StatefulSet |
| One-time batch task | Job |
| Database migration | Job |
| Scheduled backup | CronJob |
| Scheduled cleanup | CronJob |
| Scheduled report generation | CronJob |

---

# 84. The Most Important Architecture to Draw on the Whiteboard

Draw this first:

```text
                    Kubernetes
                        |
                        v
                Desired State
                        |
                        v
                +---------------+
                |  Controller   |
                +-------+-------+
                        |
                     Observe
                        |
                        v
                 Actual State
                        |
                 Difference?
                    /       \
                  No         Yes
                  |           |
                  |           v
                  |       Take Action
                  |           |
                  +-----------+
                       Watch
```

Then draw:

```text
                Deployment
                     |
                     v
                ReplicaSet
                     |
             +-------+-------+
             |       |       |
             v       v       v
            Pod     Pod     Pod
```

Then:

```text
DaemonSet
   |
   +--> Node 1 -> Pod
   +--> Node 2 -> Pod
   +--> Node 3 -> Pod
```

Then:

```text
StatefulSet
   |
   +--> app-0 -> PVC
   +--> app-1 -> PVC
   +--> app-2 -> PVC
```

Then:

```text
CronJob
   |
   v
 Job
   |
   v
 Pod
```

---

# 85. Suggested 60-Minute Session Plan

## 0–10 Minutes: Why Controllers?

Cover:

- Manual Pod management problem
- Pod failure
- Desired vs actual state
- Self-healing
- Reconciliation loop

Key sentence:

> "Kubernetes is not simply running containers; it is continuously working to maintain the state we declare."

---

## 10–20 Minutes: ReplicaSet and Deployment

Cover:

- ReplicaSet
- Replica count
- Pod failure
- Deployment
- Rolling update
- Rollback
- Deployment → ReplicaSet → Pod

Demo:

```bash
kubectl create deployment nginx --image=nginx
kubectl scale deployment nginx --replicas=3
kubectl get deploy,rs,pods
kubectl delete pod <pod-name>
kubectl get pods -w
```

---

## 20–30 Minutes: DaemonSet

Cover:

- One Pod per eligible node
- Logging
- Monitoring
- Security agents
- New node behavior
- Deployment vs DaemonSet

Demo:

```bash
kubectl get daemonset
kubectl get pods -o wide
```

---

## 30–40 Minutes: StatefulSet

Cover:

- Stateless vs stateful
- Stable identity
- Stable storage association
- Ordered behavior
- StatefulSet vs Deployment

Draw:

```text
db-0 -> PVC-0
db-1 -> PVC-1
db-2 -> PVC-2
```

---

## 40–50 Minutes: Job and CronJob

Cover:

- Finite task
- Completion
- Retry
- Parallelism
- Scheduling
- CronJob → Job → Pod

---

## 50–60 Minutes: Interview + Real-World Scenarios

Ask participants:

1. You need 10 API replicas. Which controller?
2. You need a logging agent on every node. Which controller?
3. You need a database with stable identity and storage. Which controller should you consider?
4. You need a database migration once. Which controller?
5. You need a backup every night. Which controller?
6. What happens if a Deployment Pod is deleted?
7. What is reconciliation?
8. Why use Deployment instead of ReplicaSet directly?

---

# 86. Final Summary

The most important concept is not memorizing controller names.

The important concept is understanding **why each controller exists**.

```text
                 Kubernetes Controllers
                          |
        +-----------------+------------------+
        |                 |                  |
        v                 v                  v
   Long-running       Node-level         Finite work
      Workload          Workload              |
        |                 |                  |
        v                 v             +----+----+
 Deployment           DaemonSet          |         |
        |                              Job      CronJob
        |
        v
 ReplicaSet
        |
        v
      Pods


Stateful workload
        |
        v
   StatefulSet
        |
        v
      Pods
```

The central principle is:

> **A Kubernetes controller continuously reconciles the actual state of the cluster toward the desired state declared by the user.**

And the controller-selection cheat sheet is:

```text
Deployment  = Stateless + replicas + rolling updates
ReplicaSet  = Maintain replica count
DaemonSet   = One Pod per eligible node
StatefulSet = Stable identity + storage/lifecycle semantics
Job         = Run task to completion
CronJob     = Run Jobs on a schedule
```

That is the foundation for understanding Kubernetes workload management.
