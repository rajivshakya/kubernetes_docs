# Kubernetes Scheduling: Node Affinity, Pod Affinity, and Pod Anti-Affinity

**Audience:** Beginners learning Kubernetes\
**Goal:** Understand the three scheduling rules and complete each
hands-on lab step by step.

------------------------------------------------------------------------

## 1. Learning Objectives

By the end of this session, you will be able to:

-   Explain how the Kubernetes scheduler chooses a node for a Pod.
-   Use **node affinity** to place a Pod on nodes with particular
    labels.
-   Use **pod affinity** to place a Pod near other matching Pods.
-   Use **pod anti-affinity** to keep matching Pods apart.
-   Distinguish hard scheduling rules (`required`) from soft preferences
    (`preferred`).
-   Verify scheduling decisions and troubleshoot Pending Pods.

## 2. Before You Start

You need a working Kubernetes cluster and `kubectl` configured to access
it. You can use Minikube, kind, a cloud cluster, or a training
environment such as Killercoda.

Check your connection:

``` bash
kubectl cluster-info
kubectl get nodes -o wide
kubectl get pods -A
```

If these commands fail, fix cluster access before continuing.

> **Important:** These labs create and delete resources in your current
> Kubernetes cluster. Use a learning cluster, not a production cluster.
> The labs use the namespace `affinity-lab`.

Create the namespace:

``` bash
kubectl create namespace affinity-lab
```

If it already exists, continue.

``` bash
kubectl get namespace affinity-lab
```

## 3. How Kubernetes Scheduling Works

A Pod describes an application that Kubernetes should run. The scheduler
chooses a suitable node for a Pod that does not yet have one.

At a high level:

1.  You submit a Pod or a Deployment.
2.  The scheduler checks which nodes satisfy the Pod's requirements,
    such as available resources, taints and tolerations, and affinity
    rules.
3.  If suitable nodes exist, the scheduler chooses one.
4.  The kubelet on that node starts the Pod's containers.

Affinity rules influence **where a Pod may or should run**. They do not
create nodes, add resources, or guarantee that an application starts
successfully.

### Three concepts at a glance

  -----------------------------------------------------------------------
  Rule                    What it matches         Main purpose
  ----------------------- ----------------------- -----------------------
  **Node affinity**       Labels on nodes         Place a Pod on nodes
                                                  with selected
                                                  characteristics

  **Pod affinity**        Labels on other Pods,   Place a Pod near
                          within a topology       matching Pods

  **Pod anti-affinity**   Labels on other Pods,   Avoid placing a Pod
                          within a topology       near matching Pods
  -----------------------------------------------------------------------

### Memory trick

-   **Node affinity:** "Choose a node with these labels."
-   **Pod affinity:** "Place me with/near Pods like these."
-   **Pod anti-affinity:** "Keep me apart from Pods like these."

------------------------------------------------------------------------

## 4. Labels and Selectors: The Foundation

Affinity rules use labels and selectors. A **label** is a key-value pair
attached to a Kubernetes object. A **selector** finds objects whose
labels match specified conditions.

### Node labels

Node labels describe a node. For example:

``` bash
kubectl get nodes --show-labels
```

Add a practice label to one node. First, copy a real node name from
`kubectl get nodes`:

``` bash
kubectl label node <NODE_NAME> workload=apps
```

Replace `<NODE_NAME>` with the actual node name; do not type the angle
brackets.

Verify:

``` bash
kubectl get nodes -L workload
```

If the label already exists and you intend to change it, use
`--overwrite`:

``` bash
kubectl label node <NODE_NAME> workload=apps --overwrite
```

### Pod labels

Pod labels describe Pods. In a Pod manifest, labels commonly appear
under `metadata.labels`:

``` yaml
metadata:
  labels:
    app: web
```

A selector such as `matchLabels: { app: web }` matches Pods with the
label `app=web`.

**Do not confuse the two:** node affinity selects using **node labels**.
Pod affinity and pod anti-affinity select **Pods by their labels**.

------------------------------------------------------------------------

## 5. Hard Rules vs Soft Preferences

Kubernetes affinity supports two broad types of scheduling behavior.

### Hard requirement

A hard rule must be satisfied for the Pod to be scheduled.

Example field:

``` yaml
requiredDuringSchedulingIgnoredDuringExecution:
```

If no eligible node satisfies the rule, the Pod usually remains
`Pending`.

### Soft preference

A soft rule expresses a preference. Kubernetes tries to honor it, but it
can choose another eligible node if necessary.

Example field:

``` yaml
preferredDuringSchedulingIgnoredDuringExecution:
```

A preferred rule does **not** mean Kubernetes will ignore other
scheduling constraints. Resources, taints, other required rules, and
other scheduler constraints still matter.

### What does `IgnoredDuringExecution` mean?

It means the rule is considered when the Pod is scheduled. If labels
later change so that the running Pod no longer matches the rule,
Kubernetes does not automatically evict that Pod just because of this
affinity rule.

------------------------------------------------------------------------

# Part 1 --- Node Affinity

## 6. What Is Node Affinity?

**Node affinity** is a scheduling rule that uses labels on nodes to
influence where a Pod runs.

For example, suppose a cluster has:

-   `node-a` labelled `workload=apps`
-   `node-b` labelled `workload=database`

If a Pod requires `workload=apps`, the scheduler can place it only on a
node that matches that label, subject to all other scheduling
constraints.

Node affinity is more expressive than `nodeSelector` because it supports
expressions such as `In`, `NotIn`, `Exists`, `DoesNotExist`, `Gt`, and
`Lt` in the appropriate contexts.

## 7. Node Affinity YAML Structure

### Required node affinity

``` yaml
affinity:
  nodeAffinity:
    requiredDuringSchedulingIgnoredDuringExecution:
      nodeSelectorTerms:
        - matchExpressions:
            - key: workload
              operator: In
              values:
                - apps
```

Meaning:

-   `affinity`: starts the affinity configuration.
-   `nodeAffinity`: rules based on node labels.
-   `requiredDuringSchedulingIgnoredDuringExecution`: the rule is
    mandatory at scheduling time.
-   `nodeSelectorTerms`: a list of alternative terms. **Terms are ORed**
    with one another.
-   `matchExpressions`: conditions inside a term. **Expressions in the
    same term are ANDed**.
-   `key`: the node-label key.
-   `operator: In`: the label value must be one of the listed values.
-   `values`: accepted values for this expression.

### Common operators

  -----------------------------------------------------------------------
  Operator                            Meaning
  ----------------------------------- -----------------------------------
  `In`                                Label key exists and its value is
                                      one of the listed values

  `NotIn`                             Label key is not set to any listed
                                      value; be careful if the key is
                                      absent

  `Exists`                            Label key exists; `values` is not
                                      used

  `DoesNotExist`                      Label key does not exist; `values`
                                      is not used

  `Gt`                                Numeric label value is greater than
                                      the specified value

  `Lt`                                Numeric label value is less than
                                      the specified value
  -----------------------------------------------------------------------

For `Gt` and `Lt`, use a single numeric string in `values`. For `Exists`
and `DoesNotExist`, omit `values`.

### Preferred node affinity

``` yaml
affinity:
  nodeAffinity:
    preferredDuringSchedulingIgnoredDuringExecution:
      - weight: 80
        preference:
          matchExpressions:
            - key: workload
              operator: In
              values:
                - apps
```

-   `weight` ranges from `1` to `100`.
-   Higher weights give the preference more influence when the scheduler
    scores eligible nodes.
-   A preferred rule is not a guarantee.

## 8. Hands-On Lab 1: Required Node Affinity

### Lab objective

Schedule a Pod onto a node labelled `workload=apps`.

### Step 1: Inspect the nodes

``` bash
kubectl get nodes
kubectl get nodes -L workload
```

Choose one node and set the label:

``` bash
kubectl label node <NODE_NAME> workload=apps --overwrite
```

Verify the label:

``` bash
kubectl get nodes -L workload
```

### Step 2: Create the Pod manifest

Create a file named `node-affinity.yaml` with this content:

``` yaml
apiVersion: v1
kind: Pod
metadata:
  name: node-affinity-demo
  namespace: affinity-lab
  labels:
    app: node-affinity-demo
spec:
  containers:
    - name: nginx
      image: nginx:1.27
      ports:
        - containerPort: 80
  affinity:
    nodeAffinity:
      requiredDuringSchedulingIgnoredDuringExecution:
        nodeSelectorTerms:
          - matchExpressions:
              - key: workload
                operator: In
                values:
                  - apps
```

### Step 3: Apply the manifest

``` bash
kubectl apply -f node-affinity.yaml
```

### Step 4: Check the Pod

``` bash
kubectl get pod node-affinity-demo -n affinity-lab -o wide
kubectl describe pod node-affinity-demo -n affinity-lab
```

Look at the `NODE` column. It should show a node that has
`workload=apps`, assuming that node is otherwise suitable and has enough
resources.

### Step 5: Test a scheduling failure

Change the required value from `apps` to a value that no node has, for
example `gpu-only`:

``` yaml
values:
  - gpu-only
```

Apply the updated manifest:

``` bash
kubectl apply -f node-affinity.yaml
kubectl describe pod node-affinity-demo -n affinity-lab
```

Because this Pod has already been scheduled, changing its affinity in
place may be rejected as an immutable Pod-spec change. The reliable way
to test the failure is to delete and recreate the Pod:

``` bash
kubectl delete pod node-affinity-demo -n affinity-lab
kubectl apply -f node-affinity.yaml
kubectl get pod node-affinity-demo -n affinity-lab -o wide
kubectl describe pod node-affinity-demo -n affinity-lab
```

The Pod should remain `Pending` if no suitable node has
`workload=gpu-only`. In the Events section, look for a message saying
that nodes did not match the node affinity/selector.

Restore the value to `apps` before continuing, then recreate the Pod.

### Step 6: Clean up this lab

``` bash
kubectl delete pod node-affinity-demo -n affinity-lab
```

You can keep the `workload=apps` label for the next labs. At the end,
remove it if you no longer need it:

``` bash
kubectl label node <NODE_NAME> workload-
```

Replace `<NODE_NAME>` with the node you labelled. Do not remove a label
that was already in use before this lab.

## 9. Hands-On Lab 2: Preferred Node Affinity

### Lab objective

Prefer nodes labelled `workload=apps`, but do not make that label a hard
requirement.

Create `preferred-node-affinity.yaml`:

``` yaml
apiVersion: v1
kind: Pod
metadata:
  name: preferred-node-affinity-demo
  namespace: affinity-lab
spec:
  containers:
    - name: nginx
      image: nginx:1.27
  affinity:
    nodeAffinity:
      preferredDuringSchedulingIgnoredDuringExecution:
        - weight: 80
          preference:
            matchExpressions:
              - key: workload
                operator: In
                values:
                  - apps
```

Apply and inspect:

``` bash
kubectl apply -f preferred-node-affinity.yaml
kubectl get pod preferred-node-affinity-demo -n affinity-lab -o wide
kubectl describe pod preferred-node-affinity-demo -n affinity-lab
```

The scheduler prefers a suitable node with `workload=apps`. If no such
node is available, it may choose another suitable node. This is a
preference, not a guarantee.

Clean up:

``` bash
kubectl delete pod preferred-node-affinity-demo -n affinity-lab
```

------------------------------------------------------------------------

# Part 2 --- Pod Affinity

## 10. What Is Pod Affinity?

**Pod affinity** uses labels on existing Pods to influence where another
Pod is scheduled.

For example, suppose a backend should run in the same zone as a cache
Pod. You can define pod affinity so that the backend prefers or requires
a topology domain containing a matching cache Pod.

Pod affinity is not simply "put Pods on the same node." The
`topologyKey` determines the domain:

-   `kubernetes.io/hostname`: the same node.
-   `topology.kubernetes.io/zone`: the same availability zone, if nodes
    have these labels.
-   `topology.kubernetes.io/region`: the same region, if labels are
    available.

A topology key is a **label key used to group nodes into topology
domains**. It is not itself a special node label or a node name.

## 11. Pod Affinity YAML Structure

``` yaml
affinity:
  podAffinity:
    requiredDuringSchedulingIgnoredDuringExecution:
      - labelSelector:
          matchLabels:
            app: cache
        topologyKey: kubernetes.io/hostname
```

Meaning:

-   `podAffinity`: rules based on other Pods.
-   `labelSelector`: identifies the Pods that the new Pod wants to be
    near.
-   `matchLabels: app: cache`: matches Pods labelled `app=cache`.
-   `topologyKey`: the node label key that defines the topology domain.
-   `requiredDuringSchedulingIgnoredDuringExecution`: the scheduler must
    find a matching Pod in the required topology domain.

The `namespaces` field can be used to search specific namespaces. If
omitted, the selector is evaluated in the incoming Pod's namespace. For
a cross-namespace rule, set `namespaces` explicitly or use a
`namespaceSelector` where appropriate.

## 12. Hands-On Lab 3: Required Pod Affinity

### Lab objective

Run a cache Pod first, then schedule a client Pod onto the same node as
that cache Pod.

This lab uses `kubernetes.io/hostname`, so matching Pods must share a
node.

### Step 1: Create the cache Pod

Create `cache-pod.yaml`:

``` yaml
apiVersion: v1
kind: Pod
metadata:
  name: cache-pod
  namespace: affinity-lab
  labels:
    app: cache
spec:
  containers:
    - name: nginx
      image: nginx:1.27
      ports:
        - containerPort: 80
```

Apply and wait for it to become ready:

``` bash
kubectl apply -f cache-pod.yaml
kubectl wait --for=condition=Ready pod/cache-pod -n affinity-lab --timeout=120s
kubectl get pod cache-pod -n affinity-lab -o wide --show-labels
```

Note the node on which `cache-pod` is running.

### Step 2: Create a Pod that requires affinity to the cache Pod

Create `pod-affinity.yaml`:

``` yaml
apiVersion: v1
kind: Pod
metadata:
  name: client-pod
  namespace: affinity-lab
  labels:
    app: client
spec:
  containers:
    - name: nginx
      image: nginx:1.27
  affinity:
    podAffinity:
      requiredDuringSchedulingIgnoredDuringExecution:
        - labelSelector:
            matchLabels:
              app: cache
          topologyKey: kubernetes.io/hostname
```

The new `client-pod` requires a matching `app=cache` Pod in the same
hostname topology domain. Since `cache-pod` is in the same namespace and
has that label, the client should be scheduled onto the same node, if
all other constraints allow it.

### Step 3: Apply and verify

``` bash
kubectl apply -f pod-affinity.yaml
kubectl get pods -n affinity-lab -o wide --show-labels
kubectl describe pod client-pod -n affinity-lab
```

Compare the `NODE` values for `cache-pod` and `client-pod`. They should
match.

### Step 4: Understand a common failure

If you create the client Pod before a matching cache Pod exists, a
required pod-affinity rule may leave the client Pod `Pending`. Create
the matching Pod, then inspect events:

``` bash
kubectl describe pod client-pod -n affinity-lab
kubectl get events -n affinity-lab --sort-by=.lastTimestamp
```

The scheduler must find a matching Pod in the required topology domain.
It also needs a node that satisfies all other scheduling requirements.

### Step 5: Clean up

``` bash
kubectl delete pod client-pod cache-pod -n affinity-lab
```

## 13. Preferred Pod Affinity

Use preferred pod affinity when co-location is desirable but not
mandatory.

Example fragment:

``` yaml
affinity:
  podAffinity:
    preferredDuringSchedulingIgnoredDuringExecution:
      - weight: 80
        podAffinityTerm:
          labelSelector:
            matchLabels:
              app: cache
          topologyKey: kubernetes.io/hostname
```

The scheduler tries to place the new Pod in a topology domain containing
a matching cache Pod. If it cannot, it may choose another suitable
domain.

------------------------------------------------------------------------

# Part 3 --- Pod Anti-Affinity

## 14. What Is Pod Anti-Affinity?

**Pod anti-affinity** is a scheduling rule that tells Kubernetes to
avoid placing a Pod in a topology domain that already contains Pods
matching a selector.

A common use case is high availability. For example, if a Deployment
runs three replicas of a web application, pod anti-affinity can spread
them across different nodes so that a single node failure is less likely
to take down every replica.

-   `topologyKey: kubernetes.io/hostname` means avoid matching Pods on
    the same node.
-   `topologyKey: topology.kubernetes.io/zone` means avoid matching Pods
    in the same zone, when the cluster's zone labels and topology
    support the rule.

**Important:** Required anti-affinity can make scheduling impossible if
there are too few eligible topology domains or other constraints prevent
placement.

## 15. Pod Anti-Affinity YAML Structure

``` yaml
affinity:
  podAntiAffinity:
    requiredDuringSchedulingIgnoredDuringExecution:
      - labelSelector:
          matchLabels:
            app: web
        topologyKey: kubernetes.io/hostname
```

This tells the scheduler not to place the incoming Pod on a node that
already contains a matching `app=web` Pod, within the selected namespace
scope and subject to the rule's topology.

### Preferred anti-affinity

``` yaml
affinity:
  podAntiAffinity:
    preferredDuringSchedulingIgnoredDuringExecution:
      - weight: 100
        podAffinityTerm:
          labelSelector:
            matchLabels:
              app: web
          topologyKey: kubernetes.io/hostname
```

This asks Kubernetes to prefer nodes that do not already contain
matching `app=web` Pods, but it does not guarantee separation.

## 16. Hands-On Lab 4: Required Pod Anti-Affinity

### Lab objective

Run two Pods with the same application label and require them to run on
different nodes.

This lab works best with at least **two schedulable worker nodes**. If
your cluster has only one suitable node, the second Pod should remain
Pending because the required rule cannot be satisfied. That is an
expected demonstration, not necessarily a YAML error.

### Step 1: Create a Deployment with required anti-affinity

Create `pod-anti-affinity.yaml`:

``` yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: web-ha
  namespace: affinity-lab
spec:
  replicas: 2
  selector:
    matchLabels:
      app: web-ha
  template:
    metadata:
      labels:
        app: web-ha
    spec:
      containers:
        - name: nginx
          image: nginx:1.27
          ports:
            - containerPort: 80
      affinity:
        podAntiAffinity:
          requiredDuringSchedulingIgnoredDuringExecution:
            - labelSelector:
                matchLabels:
                  app: web-ha
              topologyKey: kubernetes.io/hostname
```

### Step 2: Apply the Deployment

``` bash
kubectl apply -f pod-anti-affinity.yaml
kubectl rollout status deployment/web-ha -n affinity-lab --timeout=120s
```

If rollout status times out, continue with the inspection commands below
rather than assuming the Deployment succeeded.

### Step 3: Verify placement

``` bash
kubectl get pods -n affinity-lab -l app=web-ha -o wide
kubectl describe pods -n affinity-lab -l app=web-ha
```

On a cluster with at least two suitable nodes, the two replicas should
be on different nodes. On a one-node cluster, one replica may remain
Pending.

### Step 4: Inspect a Pending replica

``` bash
kubectl get pods -n affinity-lab -o wide
kubectl describe pod <PENDING_POD_NAME> -n affinity-lab
kubectl get events -n affinity-lab --sort-by=.lastTimestamp
```

Replace `<PENDING_POD_NAME>` with the actual Pending Pod name. Look for
events indicating that the pod anti-affinity rule could not be
satisfied.

### Step 5: Clean up

``` bash
kubectl delete deployment web-ha -n affinity-lab
```

## 17. Hands-On Lab 5: Preferred Pod Anti-Affinity

### Lab objective

Prefer to spread replicas across nodes, but allow multiple replicas on
the same node if required.

Create `preferred-pod-anti-affinity.yaml`:

``` yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: web-spread
  namespace: affinity-lab
spec:
  replicas: 3
  selector:
    matchLabels:
      app: web-spread
  template:
    metadata:
      labels:
        app: web-spread
    spec:
      containers:
        - name: nginx
          image: nginx:1.27
          ports:
            - containerPort: 80
      affinity:
        podAntiAffinity:
          preferredDuringSchedulingIgnoredDuringExecution:
            - weight: 100
              podAffinityTerm:
                labelSelector:
                  matchLabels:
                    app: web-spread
                topologyKey: kubernetes.io/hostname
```

Apply and inspect:

``` bash
kubectl apply -f preferred-pod-anti-affinity.yaml
kubectl rollout status deployment/web-spread -n affinity-lab --timeout=120s
kubectl get pods -n affinity-lab -l app=web-spread -o wide
```

Kubernetes tries to spread the replicas across nodes, but if only one
suitable node is available, all replicas may still run there if
resources permit.

Clean up:

``` bash
kubectl delete deployment web-spread -n affinity-lab
```

------------------------------------------------------------------------

## 18. Comparison: Node Affinity vs Pod Affinity vs Pod Anti-Affinity

  ---------------------------------------------------------------------------------------------------------
  Feature           Node affinity                                       Pod affinity      Pod anti-affinity
  ----------------- --------------------------------------------------- ----------------- -----------------
  Selects based on  Node labels                                         Labels of other   Labels of other
                                                                        Pods              Pods

  Goal              Choose nodes with certain properties                Co-locate with    Separate from
                                                                        matching Pods in  matching Pods in
                                                                        a topology        a topology

  Example           Run on `workload=apps` nodes                        Run on the same   Keep web replicas
                                                                        node as a cache   on different
                                                                        Pod               nodes

  Topology key      Not used                                            Required in       Required in
                                                                        affinity terms    anti-affinity
                                                                                          terms

  Hard option       `requiredDuringSchedulingIgnoredDuringExecution`    Same              Same

  Soft option       `preferredDuringSchedulingIgnoredDuringExecution`   Same              Same
  ---------------------------------------------------------------------------------------------------------

## 19. Troubleshooting Checklist

If a Pod remains `Pending`, follow this sequence:

### Step 1: Check the Pod state

``` bash
kubectl get pods -n affinity-lab -o wide
```

### Step 2: Read the events

``` bash
kubectl describe pod <POD_NAME> -n affinity-lab
kubectl get events -n affinity-lab --sort-by=.lastTimestamp
```

Replace `<POD_NAME>` with the real Pod name.

### Step 3: Check node labels

``` bash
kubectl get nodes --show-labels
kubectl get nodes -L workload
```

For node affinity, verify the required label key and value exactly.

### Step 4: Check the matching Pods

``` bash
kubectl get pods -n affinity-lab --show-labels -o wide
```

For pod affinity and anti-affinity, verify the selector matches the
intended Pods and that the Pods are in the expected namespace.

### Step 5: Check topology labels

``` bash
kubectl get nodes -L kubernetes.io/hostname,topology.kubernetes.io/zone
```

Confirm that the topology key exists on nodes where the rule needs to
operate.

### Step 6: Check other constraints

Even if affinity matches, a Pod may not schedule because of:

-   Insufficient CPU or memory.
-   Node taints without matching tolerations.
-   Node unschedulability or cordoning.
-   Other required affinity or selector rules.
-   Storage or other scheduling constraints.

Use `kubectl describe pod` and the Events section to identify the actual
reason.

## 20. Best Practices

1.  Use **required** affinity only when placement is essential;
    otherwise it can leave Pods Pending.
2.  Prefer **soft anti-affinity** when a cluster may not have enough
    nodes to satisfy strict separation.
3.  Use stable, meaningful labels such as `app`, `tier`, and `workload`.
4.  Pick `topologyKey` carefully. Hostname means a node; zone means an
    availability zone.
5.  For high availability, consider topology spread constraints as
    another tool for spreading replicas.
6.  Test rules in a non-production namespace before using them in
    production.
7.  Remember that affinity rules guide scheduling; they do not replace
    resource requests, health checks, or application-level resilience.

## 21. Interview-Ready Answers

**Q1. What is node affinity?**\
Node affinity is a Kubernetes scheduling feature that places or prefers
Pods on nodes whose labels match specified rules. It supports required
rules and weighted preferences.

**Q2. What is pod affinity?**\
Pod affinity places or prefers a Pod in a topology domain that contains
other Pods matching a label selector. For example, it can place a client
Pod on the same node as a cache Pod.

**Q3. What is pod anti-affinity?**\
Pod anti-affinity avoids or prefers avoiding a topology domain that
contains Pods matching a label selector. It is commonly used to spread
application replicas for better availability.

**Q4. What is the difference between required and preferred?**\
Required is a hard scheduling constraint. Preferred is a soft preference
that the scheduler tries to honor when choosing among otherwise eligible
nodes.

**Q5. What is `topologyKey`?**\
`topologyKey` is the node-label key used to group nodes into topology
domains. `kubernetes.io/hostname` defines a node-level domain;
`topology.kubernetes.io/zone` can define a zone-level domain.

**Q6. Will a running Pod be evicted if its affinity rule stops matching
after a label changes?**\
Not just because of these `IgnoredDuringExecution` affinity rules. The
rules affect scheduling, and they do not automatically evict an
already-running Pod when labels later change.

**Q7. Why might a Pod remain Pending with required pod anti-affinity?**\
There may be no eligible topology domain without a matching Pod. For
example, two replicas cannot satisfy required hostname anti-affinity on
a cluster with only one suitable node.

## 22. Quick Recap

-   **Node affinity:** select nodes using node labels.
-   **Pod affinity:** co-locate with matching Pods within a topology.
-   **Pod anti-affinity:** avoid co-locating with matching Pods within a
    topology.
-   **Required:** must match for scheduling.
-   **Preferred:** try to match, but another eligible placement may be
    used.
-   **`topologyKey`:** determines whether the rule works at node, zone,
    or another labelled topology level.

## 23. Final Cleanup

Delete any resources left from the labs:

``` bash
kubectl delete pod node-affinity-demo preferred-node-affinity-demo cache-pod client-pod -n affinity-lab --ignore-not-found
kubectl delete deployment web-ha web-spread -n affinity-lab --ignore-not-found
```

If you no longer need the practice namespace:

``` bash
kubectl delete namespace affinity-lab
```

Only delete the namespace if it contains no other work you want to keep.

------------------------------------------------------------------------

**End of notes.** Use the labs in order: node affinity → pod affinity →
pod anti-affinity. For each lab, apply the YAML, inspect placement with
`kubectl get ... -o wide`, and use `kubectl describe` when the result
differs from expectations.
