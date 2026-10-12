# Kubernetes Taints and Tolerations

**Hands-On DevOps Session \| 12 October 2026**

> **Session goal:** Understand how Kubernetes controls which Pods can be
> scheduled on which Nodes using taints and tolerations, compare this
> with labels and selectors, and practise applying, updating, and
> removing taints.

## 1. What are Taints and Tolerations?

### Taint

A **taint** is applied to a **Node**. It tells Kubernetes: "Do not
schedule Pods on this Node unless they tolerate this taint."

A taint has three parts:

``` text
key=value:effect
```

Example:

``` bash
kubectl taint nodes worker-1 workload=production:NoSchedule
```

-   `workload` --- key
-   `production` --- value
-   `NoSchedule` --- effect

### Toleration

A **toleration** is defined in a **Pod specification**. It tells
Kubernetes that the Pod is allowed to be scheduled onto a Node with a
matching taint.

A toleration **does not force** a Pod onto that Node. It only removes
the taint-based restriction. Other scheduling requirements still apply.

Example:

``` yaml
tolerations:
  - key: "workload"
    operator: "Equal"
    value: "production"
    effect: "NoSchedule"
```

### Easy way to remember

-   **Taint = restriction on a Node**
-   **Toleration = permission for a Pod to pass that restriction**
-   A matching toleration makes scheduling *allowed*, not guaranteed.

## 2. Why do we use them? (Real-world use cases)

1.  **Dedicated production Nodes:** Keep production workloads away from
    general workloads.
2.  **GPU Nodes:** Reserve expensive GPU capacity for Pods that need it.
3.  **Special hardware or licensed workloads:** Restrict placement to
    Nodes with specific capabilities.
4.  **System or infrastructure Nodes:** Keep ordinary application Pods
    away from Nodes reserved for infrastructure.
5.  **Maintenance and unhealthy Nodes:** Use taints such as `NoSchedule`
    or `NoExecute` to influence scheduling or evict existing Pods.
6.  **Cluster operations:** Kubernetes adds certain taints for
    conditions such as memory pressure, disk pressure, and not-ready
    Nodes.

> **Important:** Taints and tolerations are not a security boundary. Use
> RBAC, admission controls, and other security controls when workloads
> must be isolated securely.

## 3. Taints vs. Labels and Node Selectors

  -----------------------------------------------------------------------
  Feature                 Taints and tolerations  Labels and nodeSelector
  ----------------------- ----------------------- -----------------------
  Main purpose            Keep Pods away unless   Select Nodes with
                          they tolerate a taint   particular labels

  Applied to              Taint: Node;            Label: Node; selector:
                          toleration: Pod         Pod

  Scheduling meaning      A taint can repel a Pod A selector requires a
                                                  matching label

  Does it guarantee       No                      A matching
  placement?                                      `nodeSelector` requires
                                                  the selected label, but
                                                  other scheduling rules
                                                  still apply

  Common use              Reserve Nodes / repel   Choose Nodes by
                          workloads               environment, region,
                                                  hardware, or role
  -----------------------------------------------------------------------

### Example: use both together

A dedicated Node can have a label and a taint:

``` bash
kubectl label node worker-1 workload=production
kubectl taint node worker-1 workload=production:NoSchedule
```

A Pod that must run on a production-labelled Node and is allowed through
the taint can specify both:

``` yaml
spec:
  nodeSelector:
    workload: production
  tolerations:
    - key: "workload"
      operator: "Equal"
      value: "production"
      effect: "NoSchedule"
```

-   `nodeSelector` says: **select a Node labelled
    `workload=production`.**
-   `tolerations` says: **allow this Pod onto a Node carrying the
    matching taint.**

Using both is a common way to reserve a group of Nodes for a particular
workload.

## 4. The three taint effects

Kubernetes taint effects are `NoSchedule`, `PreferNoSchedule`, and
`NoExecute`.

### 4.1 `NoSchedule` --- hard scheduling restriction

``` bash
kubectl taint nodes worker-1 dedicated=payments:NoSchedule
```

-   A new Pod without a matching toleration will not be scheduled onto
    this Node because of this taint.
-   A Pod already running on the Node is not evicted merely because this
    taint is added.
-   A Pod with a matching toleration may be scheduled there, subject to
    other scheduling rules.

**Remember:** `NoSchedule` blocks new scheduling; it does not itself
evict existing Pods.

### 4.2 `PreferNoSchedule` --- soft scheduling preference

``` bash
kubectl taint nodes worker-1 dedicated=payments:PreferNoSchedule
```

-   Kubernetes tries to avoid placing Pods that do not tolerate the
    taint on this Node.
-   It is a preference, not a guarantee. The scheduler may still place a
    Pod there if appropriate alternatives are unavailable.
-   It does not evict existing Pods merely because the taint is added.

**Remember:** "Prefer not to schedule" is a soft rule, not an absolute
block.

### 4.3 `NoExecute` --- scheduling restriction plus eviction

``` bash
kubectl taint nodes worker-1 dedicated=payments:NoExecute
```

-   A new Pod without a matching toleration will not be scheduled onto
    the Node.
-   Existing Pods on the Node that do not tolerate the taint are
    evicted.
-   A Pod with a matching toleration can remain. A `tolerationSeconds`
    value can limit how long it stays after the taint is added.

Example toleration with a time limit:

``` yaml
tolerations:
  - key: "dedicated"
    operator: "Equal"
    value: "payments"
    effect: "NoExecute"
    tolerationSeconds: 300
```

This Pod can tolerate the taint for **300 seconds (5 minutes)** after it
is applied. After that, it may be evicted if the taint remains.

### Quick comparison

  -----------------------------------------------------------------------
  Effect                  New Pod without         Existing Pod without
                          toleration              toleration
  ----------------------- ----------------------- -----------------------
  `NoSchedule`            Not scheduled onto the  Stays running
                          tainted Node            

  `PreferNoSchedule`      Scheduler tries to      Stays running
                          avoid the Node, but may 
                          schedule there          

  `NoExecute`             Not scheduled onto the  Evicted
                          tainted Node            
  -----------------------------------------------------------------------

## 5. How to inspect, apply, and remove taints

### View Nodes

``` bash
kubectl get nodes
kubectl get nodes -o wide
```

### Inspect taints on a Node

``` bash
kubectl describe node worker-1
```

Look for the **Taints** field in the output.

You can also print taints for all Nodes:

``` bash
kubectl get nodes -o custom-columns=NAME:.metadata.name,TAINTS:.spec.taints
```

### Add a taint

``` bash
kubectl taint nodes worker-1 workload=production:NoSchedule
```

### Update a taint effect or value

Taints are identified by their key and effect when updating/removing
them. To replace an existing taint with the same key and effect but a
different value, use the overwrite option:

``` bash
kubectl taint nodes worker-1 workload=staging:NoSchedule --overwrite
```

For a clear learning demo, you can remove the old taint and add the new
one instead.

### Remove a taint

Add a trailing hyphen (`-`) after the taint effect:

``` bash
kubectl taint nodes worker-1 workload=production:NoSchedule-
```

The trailing `-` means **remove this taint**.

Remove all taints with a particular key (use carefully):

``` bash
kubectl taint nodes worker-1 workload-
```

> **Caution:** Use a lab Node or a Node you are authorised to modify. Do
> not remove built-in Kubernetes taints blindly, particularly taints
> related to health or control-plane behaviour.

## 6. Defining tolerations in a Pod YAML

### Example A: match a taint exactly

Suppose the Node has:

``` bash
kubectl taint nodes worker-1 workload=production:NoSchedule
```

Create `toleration-pod.yaml`:

``` yaml
apiVersion: v1
kind: Pod
metadata:
  name: production-pod
spec:
  containers:
    - name: nginx
      image: nginx:1.27
  tolerations:
    - key: "workload"
      operator: "Equal"
      value: "production"
      effect: "NoSchedule"
```

Apply and inspect it:

``` bash
kubectl apply -f toleration-pod.yaml
kubectl get pod production-pod -o wide
kubectl describe pod production-pod
```

**What this demonstrates:** The Pod tolerates the matching taint. It is
eligible to run on the Node, but Kubernetes does not promise it will
land on `worker-1` unless placement requirements make that happen.

### Example B: `Exists` operator

`Exists` matches a taint key regardless of its value. Do not specify a
`value` when using `Exists`.

``` yaml
tolerations:
  - key: "workload"
    operator: "Exists"
    effect: "NoSchedule"
```

This tolerates `workload=<any-value>:NoSchedule`, but it does not
tolerate taints with a different key or a different effect.

### Example C: tolerate any key with `Exists`

``` yaml
tolerations:
  - operator: "Exists"
    effect: "NoSchedule"
```

This tolerates any taint key with the `NoSchedule` effect. This is broad
and should be used only when that behaviour is intentional.

### `Equal` vs. `Exists`

  -----------------------------------------------------------------------
  Operator                Matching behaviour      Value
  ----------------------- ----------------------- -----------------------
  `Equal`                 Key, value, and effect  Required
                          must match              

  `Exists`                Key and effect must     Must be omitted
                          match; value is ignored 
  -----------------------------------------------------------------------

If `operator` is omitted, Kubernetes defaults it to `Equal`.

## 7. Hands-on lab: reserve a Node for a workload

**Prerequisites:** A Kubernetes cluster with at least one worker Node
you can safely modify. Replace `worker-1` with a real Node name from
your cluster. A single-node lab can demonstrate the taint but may leave
Pods Pending.

### Step 1 --- list your Nodes

``` bash
kubectl get nodes
```

Choose a lab Node and set its name in the commands below.

### Step 2 --- add a taint

``` bash
kubectl taint nodes worker-1 dedicated=demo:NoSchedule
kubectl describe node worker-1
```

Expected observation: the Node's `Taints` field includes
`dedicated=demo:NoSchedule`.

### Step 3 --- create a Pod without a toleration

Save as `pod-without-toleration.yaml`:

``` yaml
apiVersion: v1
kind: Pod
metadata:
  name: pod-without-toleration
spec:
  containers:
    - name: nginx
      image: nginx:1.27
```

Apply it:

``` bash
kubectl apply -f pod-without-toleration.yaml
kubectl get pod pod-without-toleration -o wide
kubectl describe pod pod-without-toleration
```

If all available Nodes have an untolerated `NoSchedule` taint, the Pod
remains `Pending`. If the cluster has other eligible Nodes, the Pod may
run on one of those instead. Check the `Events` section in `describe`
for scheduling reasons.

### Step 4 --- create a Pod with a toleration

Save as `pod-with-toleration.yaml`:

``` yaml
apiVersion: v1
kind: Pod
metadata:
  name: pod-with-toleration
spec:
  containers:
    - name: nginx
      image: nginx:1.27
  tolerations:
    - key: "dedicated"
      operator: "Equal"
      value: "demo"
      effect: "NoSchedule"
```

Apply it:

``` bash
kubectl apply -f pod-with-toleration.yaml
kubectl get pod pod-with-toleration -o wide
kubectl describe pod pod-with-toleration
```

The Pod can now tolerate the taint. If you need to demonstrate that it
lands specifically on `worker-1`, add a Node label and matching
`nodeSelector` (as shown in Section 3). Without that selector,
Kubernetes may choose another eligible Node.

### Step 5 --- remove the taint

``` bash
kubectl taint nodes worker-1 dedicated=demo:NoSchedule-
kubectl describe node worker-1
```

The taint should no longer appear. Removing the taint does not delete
Pods; it changes the scheduling restriction going forward.

### Step 6 --- clean up the lab Pods

``` bash
kubectl delete pod pod-without-toleration pod-with-toleration
```

## 8. Built-in taints and node conditions

Kubernetes can apply taints automatically for Node conditions. Common
examples include:

-   `node.kubernetes.io/not-ready`
-   `node.kubernetes.io/unreachable`
-   `node.kubernetes.io/memory-pressure`
-   `node.kubernetes.io/disk-pressure`
-   `node.kubernetes.io/pid-pressure`

For example, a Node that is not ready may be tainted so that new
workloads are not placed there and existing workloads may be handled
according to the applicable taint and toleration behaviour.

Kubernetes also uses taints to control workloads on control-plane Nodes.
The exact taints and tolerations depend on cluster setup and version.
Inspect the cluster rather than assuming every cluster is configured
identically:

``` bash
kubectl describe node <node-name>
```

## 9. Common mistakes and troubleshooting

1.  **Key mismatch:** `dedicated` and `workload` are different keys.
2.  **Value mismatch with `Equal`:** `demo` does not match `production`.
3.  **Effect mismatch:** A `NoSchedule` toleration does not match a
    `NoExecute` taint.
4.  **Expecting a toleration to select a Node:** It does not. Use
    `nodeSelector` or node affinity when specific placement is required.
5.  **Expecting `NoSchedule` to evict Pods:** It does not; `NoExecute`
    is the effect associated with eviction.
6.  **Pod still Pending:** Check all Nodes, resource requests,
    affinity/selectors, PVC constraints, and scheduling Events.
7.  **Taint already exists:** Inspect it with
    `kubectl describe node <node-name>` before adding or changing it.
8.  **Broad tolerations:** A toleration with `operator: Exists` and no
    key may tolerate many taints. Avoid it unless needed.

Useful commands:

``` bash
kubectl get nodes
kubectl describe node <node-name>
kubectl get pods -o wide
kubectl describe pod <pod-name>
kubectl get events --sort-by=.metadata.creationTimestamp
```

## 10. Interview-ready questions and answers

**Q1. What is a taint?**\
A taint is applied to a Node and repels Pods that do not have a matching
toleration, depending on the effect.

**Q2. What is a toleration?**\
A toleration is specified in a Pod and allows it to tolerate a matching
Node taint. It does not guarantee placement on that Node.

**Q3. What is the difference between `NoSchedule` and `NoExecute`?**\
`NoSchedule` prevents new non-tolerating Pods from being scheduled onto
the Node but does not evict existing Pods. `NoExecute` also evicts
existing Pods that do not tolerate the taint.

**Q4. What does `PreferNoSchedule` do?**\
It asks the scheduler to avoid the Node where possible, but it is not a
hard guarantee.

**Q5. How are taints different from labels?**\
Taints repel Pods unless tolerated. Labels identify Nodes;
`nodeSelector` or node affinity lets a Pod select Nodes with matching
labels.

**Q6. Does adding a toleration guarantee that a Pod runs on the tainted
Node?**\
No. It only removes the taint-based barrier. Resources, selectors,
affinity, topology rules, and other scheduling constraints still apply.

**Q7. How do you remove a taint?**\
Use `kubectl taint nodes <node-name> <key>:<effect>-`, for example
`kubectl taint nodes worker-1 dedicated=demo:NoSchedule-`.

**Q8. What is `tolerationSeconds`?**\
It specifies how long a Pod can remain on a Node after a matching
`NoExecute` taint is applied. It is used with `NoExecute` tolerations.

## 11. Final recap

-   **Taint:** Node-side restriction.
-   **Toleration:** Pod-side permission to tolerate that restriction.
-   **`NoSchedule`:** Do not schedule new non-tolerating Pods.
-   **`PreferNoSchedule`:** Avoid scheduling there when possible.
-   **`NoExecute`:** Do not schedule non-tolerating Pods and evict
    existing non-tolerating Pods.
-   **Labels + selectors:** Select Nodes.
-   **Taints + tolerations:** Repel workloads unless they tolerate the
    taint.
-   **Use both together** when you need to reserve Nodes and also target
    workloads to those Nodes.

### Suggested live-demo flow

1.  Explain the Node taint and Pod toleration.
2.  Show the difference between a taint and a Node label.
3.  Apply `NoSchedule`; observe scheduling Events.
4.  Add the toleration; observe Pod placement.
5.  Explain why toleration alone does not guarantee placement.
6.  Remove the taint and clean up the lab.

**Official reference:** [Kubernetes --- Taints and
Tolerations](https://kubernetes.io/docs/concepts/scheduling-eviction/taint-and-toleration/)
