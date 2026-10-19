# Kubernetes Resource Management: Requests, Limits, LimitRange, ResourceQuota, and QoS

## 1. Introduction

Every Kubernetes container uses resources from a worker node, mainly:

- **CPU** — used to process tasks.
- **Memory** — used to store data while an application is running.

Kubernetes provides resource management features to control how much CPU and memory applications request and consume.

In this session, we will learn:

1. Resource Requests
2. Resource Limits
3. Requests vs. Limits
4. LimitRange
5. ResourceQuota
6. Quality of Service (QoS) classes
7. How to check and troubleshoot resources
8. A complete hands-on practical

---

## 2. Resource Requests

### What is a Resource Request?

A **resource request** defines the amount of CPU or memory Kubernetes uses when deciding whether a worker node has enough resources to schedule a container.

### Example

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: request-pod
spec:
  containers:
    - name: nginx
      image: nginx
      resources:
        requests:
          cpu: "250m"
          memory: "128Mi"
```

### Explanation

- `cpu: "250m"` means 0.25 CPU core.
- `memory: "128Mi"` means 128 mebibytes of memory.
- Kubernetes considers these requests when scheduling the Pod.

**Important:** A request is not a hard limit on usage. A container can use more than its request if resources are available and no other restriction prevents it.

### Where do we define Requests?

Requests are defined in the container's `resources.requests` field inside the Pod specification. You can define them directly in a Pod or in the Pod template of a Deployment, StatefulSet, or another workload.

---

## 3. Resource Limits

### What is a Resource Limit?

A **resource limit** defines the maximum amount of CPU or memory a container is allowed to use.

### Example

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: limit-pod
spec:
  containers:
    - name: nginx
      image: nginx
      resources:
        requests:
          cpu: "250m"
          memory: "128Mi"
        limits:
          cpu: "500m"
          memory: "256Mi"
```

### Explanation

| Resource | Request | Limit |
|---|---:|---:|
| CPU | 250m | 500m |
| Memory | 128Mi | 256Mi |

- Kubernetes schedules the Pod based on its requests.
- The container can use up to 500m CPU.
- The container is limited to 256Mi memory.

### What happens when a container reaches its limit?

**CPU limit:** CPU usage is throttled when the container tries to use more CPU than its configured limit.

**Memory limit:** If the container exceeds its memory limit, it can be terminated by the Linux out-of-memory mechanism (OOM killer). Kubernetes may restart it according to its restart policy. You may see `OOMKilled` in the container status.

### Where do we define Limits?

Limits are defined in the container's `resources.limits` field inside the Pod specification.

---

## 4. Difference Between Requests and Limits

| Feature | Requests | Limits |
|---|---|---|
| Purpose | Help Kubernetes schedule Pods | Restrict container resource usage |
| CPU | Used for scheduling decisions | CPU usage is throttled |
| Memory | Used for scheduling decisions | Exceeding the limit can cause OOM termination |
| Defined at | Container level | Container level |
| Main benefit | Better scheduling | Resource protection |

### Easy example

```yaml
resources:
  requests:
    cpu: "250m"
    memory: "128Mi"
  limits:
    cpu: "500m"
    memory: "256Mi"
```

Think of it like this:

- **Request:** Kubernetes plans for 250m CPU and 128Mi memory when scheduling.
- **Limit:** The container is restricted to 500m CPU and 256Mi memory.

CPU requests are not a hard minimum guarantee of actual CPU time, and memory requests do not reserve a separate physical block of RAM.

---

## 5. Resource Units

### CPU units

| Value | Meaning |
|---|---|
| `1` | 1 CPU core |
| `500m` | 0.5 CPU core |
| `250m` | 0.25 CPU core |
| `100m` | 0.1 CPU core |

Here, `m` means millicore. One CPU core equals 1000 millicores.

### Memory units

| Value | Meaning |
|---|---|
| `128Mi` | 128 mebibytes |
| `256Mi` | 256 mebibytes |
| `512Mi` | 512 mebibytes |
| `1Gi` | 1 gibibyte |

`Mi` and `Gi` are binary units. `M` and `G` are decimal units, so they are not exactly equivalent.

---

## 6. What Is LimitRange?

### Definition

A **LimitRange** is a Kubernetes object used to define default, minimum, and maximum resource requirements for containers or Pods within a namespace.

It helps administrators enforce resource settings for individual workloads.

### Why do we need LimitRange?

Suppose a developer creates a Pod without specifying CPU or memory requests and limits. A LimitRange can provide default values and enforce allowed resource ranges.

### Example: Create a LimitRange

First, create a namespace:

```bash
kubectl create namespace dev
```

Create a file named `limitrange.yaml`:

```yaml
apiVersion: v1
kind: LimitRange
metadata:
  name: resource-limits
  namespace: dev
spec:
  limits:
    - type: Container
      defaultRequest:
        cpu: "100m"
        memory: "64Mi"
      default:
        cpu: "500m"
        memory: "256Mi"
      min:
        cpu: "50m"
        memory: "32Mi"
      max:
        cpu: "1"
        memory: "512Mi"
```

Apply the configuration:

```bash
kubectl apply -f limitrange.yaml
```

### Explanation

| Field | Meaning |
|---|---|
| `defaultRequest` | Request values added when requests are omitted |
| `default` | Limit values added when limits are omitted |
| `min` | Minimum permitted resource values |
| `max` | Maximum permitted resource values |

In this example, a container's CPU request and limit must each be within 50m and 1 CPU, and its memory request and limit must each be within 32Mi and 512Mi.

**Important:** Defaults and bounds are applied during admission. A Pod that violates applicable constraints is rejected.

### Test the LimitRange

Create `test-pod.yaml`:

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: nginx-default
  namespace: dev
spec:
  containers:
    - name: nginx
      image: nginx
```

Apply it:

```bash
kubectl apply -f test-pod.yaml
```

Check the resource settings:

```bash
kubectl get pod nginx-default -n dev -o yaml
```

Look for values similar to:

```yaml
resources:
  requests:
    cpu: 100m
    memory: 64Mi
  limits:
    cpu: 500m
    memory: 256Mi
```

Kubernetes has added the default values from the LimitRange.

### Test the maximum value

Create `nginx-too-large.yaml` with a memory limit of `1Gi`, which exceeds the configured maximum of `512Mi`:

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: nginx-too-large
  namespace: dev
spec:
  containers:
    - name: nginx
      image: nginx
      resources:
        limits:
          memory: "1Gi"
```

Apply it:

```bash
kubectl apply -f nginx-too-large.yaml
```

Expected result: Kubernetes rejects the Pod because its memory limit exceeds the LimitRange maximum.

### Where do we define LimitRange?

**Namespace level.** A LimitRange applies to the namespace specified in its metadata. It does not automatically apply to every namespace in the cluster.

---

## 7. What Is ResourceQuota?

### Definition

A **ResourceQuota** is a Kubernetes object used to limit the total amount of resources or the number of objects that can be consumed within a namespace.

Unlike a LimitRange, which defines rules for individual containers or Pods, a ResourceQuota controls aggregate usage across a namespace.

### Why do we need ResourceQuota?

Imagine a namespace has 20 developers. Without a quota, their workloads could collectively request a large amount of CPU and memory. An administrator can use ResourceQuota to control the total resource requests, limits, and other supported resources in that namespace.

### Example: Create a ResourceQuota

Create `resourcequota.yaml`:

```yaml
apiVersion: v1
kind: ResourceQuota
metadata:
  name: dev-quota
  namespace: dev
spec:
  hard:
    requests.cpu: "2"
    requests.memory: "2Gi"
    limits.cpu: "4"
    limits.memory: "4Gi"
    pods: "10"
```

Apply it:

```bash
kubectl apply -f resourcequota.yaml
```

### Explanation

| Quota | Maximum namespace total |
|---|---:|
| `requests.cpu` | 2 CPU cores |
| `requests.memory` | 2Gi |
| `limits.cpu` | 4 CPU cores |
| `limits.memory` | 4Gi |
| `pods` | 10 Pods |

These are namespace-wide totals, not per-container values.

For example, if existing Pods consume 1.5 CPU cores in total requests, only another 0.5 CPU core of request quota remains available.

### Test the ResourceQuota

Check the quota:

```bash
kubectl get resourcequota -n dev
```

View detailed information:

```bash
kubectl describe resourcequota dev-quota -n dev
```

Example output (actual values depend on your namespace):

```text
Resource           Used    Hard
--------           ----    ----
pods               1       10
requests.cpu       100m    2
requests.memory    64Mi    2Gi
limits.cpu         500m    4
limits.memory      256Mi   4Gi
```

### What happens when the quota is exceeded?

Suppose the namespace has already consumed its allowed CPU request quota. A new Pod requests another 1 CPU core, taking the total above the quota. Kubernetes rejects the Pod creation with a quota-exceeded error.

Existing Pods are not automatically terminated just because a new Pod would exceed the quota.

### Important note

When a quota requires CPU or memory requests or limits, new containers must specify those resources or receive valid defaults through a LimitRange. Otherwise, Pod creation may fail.

### Where do we define ResourceQuota?

**Namespace level.** ResourceQuota applies to the namespace specified in its metadata. It does not automatically apply to other namespaces.

---

## 8. Difference Between LimitRange and ResourceQuota

| Feature | LimitRange | ResourceQuota |
|---|---|---|
| Purpose | Control individual resource settings | Control total namespace consumption |
| Scope | Namespace | Namespace |
| Controls | Defaults, minimums, maximums | Aggregate CPU, memory, Pod count, and other supported resources |
| Example | A container's memory limit cannot exceed 512Mi | Total memory requests cannot exceed 2Gi |
| Main use | Prevent individual workloads from requesting unsuitable resources | Prevent a namespace from consuming too many resources |

### Easy example

Suppose the `dev` namespace has:

- A LimitRange allowing a maximum of 512Mi memory per container.
- A ResourceQuota allowing a total of 2Gi memory requests.

If a container requests 1Gi memory, it violates the LimitRange.

If each container stays within the LimitRange but the combined memory requests exceed 2Gi, the ResourceQuota prevents additional requests from being admitted.

Both objects can work together in the same namespace.

---

## 9. What Is QoS in Kubernetes?

### Definition

QoS stands for **Quality of Service**.

Kubernetes assigns a QoS class to each Pod based on the CPU and memory requests and limits of its containers.

QoS helps Kubernetes determine which Pods are more suitable candidates for eviction when a node experiences resource pressure, particularly memory pressure.

The three QoS classes are:

1. Guaranteed
2. Burstable
3. BestEffort

### 9.1 Guaranteed

A Pod receives the `Guaranteed` QoS class when every container has CPU and memory requests and limits configured, and each CPU request equals its CPU limit and each memory request equals its memory limit.

Example:

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: guaranteed-pod
spec:
  containers:
    - name: nginx
      image: nginx
      resources:
        requests:
          cpu: "500m"
          memory: "256Mi"
        limits:
          cpu: "500m"
          memory: "256Mi"
```

Check its QoS class:

```bash
kubectl get pod guaranteed-pod -o jsonpath='{.status.qosClass}'
```

Expected output:

```text
Guaranteed
```

### 9.2 Burstable

A Pod receives the `Burstable` QoS class when it does not meet the Guaranteed criteria but at least one container has a CPU or memory request or limit configured.

Example:

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: burstable-pod
spec:
  containers:
    - name: nginx
      image: nginx
      resources:
        requests:
          cpu: "250m"
          memory: "128Mi"
        limits:
          cpu: "500m"
          memory: "256Mi"
```

Check its QoS class:

```bash
kubectl get pod burstable-pod -o jsonpath='{.status.qosClass}'
```

Expected output:

```text
Burstable
```

### 9.3 BestEffort

A Pod receives the `BestEffort` QoS class when none of its containers has CPU or memory requests or limits configured.

Example:

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: besteffort-pod
spec:
  containers:
    - name: nginx
      image: nginx
```

Check its QoS class:

```bash
kubectl get pod besteffort-pod -o jsonpath='{.status.qosClass}'
```

Expected output:

```text
BestEffort
```

### Difference Between QoS Classes

| QoS class | Resource configuration | General eviction risk |
|---|---|---|
| Guaranteed | CPU and memory requests equal limits for every container | Generally lowest |
| Burstable | Some resource requests or limits are configured | Depends on usage and other factors |
| BestEffort | No CPU or memory requests or limits are configured | Generally highest |

**Important:** This is a general guide, not an absolute eviction order. Actual eviction decisions depend on node conditions, resource usage relative to requests, and other factors. Guaranteed Pods can also be terminated under resource pressure.

---

## 10. How to Check Resource Configuration

### Check Pods

```bash
kubectl get pods -n dev
```

### Check CPU and memory requests and limits

```bash
kubectl describe pod nginx-default -n dev
```

Look for the `Requests` and `Limits` sections under the container details.

### Check LimitRange

```bash
kubectl get limitrange -n dev
kubectl describe limitrange resource-limits -n dev
```

### Check ResourceQuota

```bash
kubectl get resourcequota -n dev
kubectl describe resourcequota dev-quota -n dev
```

### Check QoS class for all Pods

```bash
kubectl get pods -n dev \
  -o custom-columns=NAME:.metadata.name,QOS:.status.qosClass
```

### Check node resource capacity and allocation

```bash
kubectl describe node <node-name>
```

Look at:

- Capacity
- Allocatable
- Allocated resources

These help you understand why a Pod may fail to schedule.

### Check actual CPU and memory usage

```bash
kubectl top pods -n dev
kubectl top nodes
```

These commands require the Kubernetes Metrics API, commonly provided by Metrics Server. They show observed usage, not configured requests and limits.

---

## 11. Where Is Each Resource Defined?

| Feature | Defined at | Configured in |
|---|---|---|
| Requests | Container level | Pod specification |
| Limits | Container level | Pod specification |
| LimitRange | Namespace level | `kind: LimitRange` |
| ResourceQuota | Namespace level | `kind: ResourceQuota` |
| QoS class | Calculated by Kubernetes | Pod status |

Remember that requests and limits are specified per container, while LimitRange and ResourceQuota are namespace-scoped policies.

---

## 12. Complete Hands-On Practical

In this practical, we will create a namespace, apply a LimitRange and ResourceQuota, create a Pod, and verify the result.

### Step 1: Create a namespace

```bash
kubectl create namespace resource-demo
```

Verify:

```bash
kubectl get namespaces
```

### Step 2: Create a LimitRange

Save the following as `limitrange.yaml`:

```yaml
apiVersion: v1
kind: LimitRange
metadata:
  name: demo-limits
  namespace: resource-demo
spec:
  limits:
    - type: Container
      defaultRequest:
        cpu: "100m"
        memory: "64Mi"
      default:
        cpu: "500m"
        memory: "256Mi"
      min:
        cpu: "50m"
        memory: "32Mi"
      max:
        cpu: "1"
        memory: "512Mi"
```

Apply:

```bash
kubectl apply -f limitrange.yaml
```

Verify:

```bash
kubectl describe limitrange demo-limits -n resource-demo
```

### Step 3: Create a ResourceQuota

Save as `resourcequota.yaml`:

```yaml
apiVersion: v1
kind: ResourceQuota
metadata:
  name: demo-quota
  namespace: resource-demo
spec:
  hard:
    requests.cpu: "1"
    requests.memory: "1Gi"
    limits.cpu: "2"
    limits.memory: "2Gi"
    pods: "5"
```

Apply:

```bash
kubectl apply -f resourcequota.yaml
```

Verify:

```bash
kubectl describe resourcequota demo-quota -n resource-demo
```

### Step 4: Create a Pod without resource settings

Save as `nginx.yaml`:

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: nginx-demo
  namespace: resource-demo
spec:
  containers:
    - name: nginx
      image: nginx
```

Apply:

```bash
kubectl apply -f nginx.yaml
```

### Step 5: Verify the default values

```bash
kubectl describe pod nginx-demo -n resource-demo
```

The container should receive these values from the LimitRange:

- CPU request: `100m`
- Memory request: `64Mi`
- CPU limit: `500m`
- Memory limit: `256Mi`

### Step 6: Verify the QoS class

```bash
kubectl get pod nginx-demo -n resource-demo \
  -o jsonpath='{.status.qosClass}'
```

Expected output:

```text
Burstable
```

The Pod is Burstable because its requests are lower than its limits.

### Step 7: Verify ResourceQuota usage

```bash
kubectl describe resourcequota demo-quota -n resource-demo
```

The Pod should contribute to the namespace's CPU, memory, and Pod-count usage.

### Step 8: Test a violation

Create `invalid-pod.yaml` with a memory limit above the LimitRange maximum:

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: invalid-pod
  namespace: resource-demo
spec:
  containers:
    - name: nginx
      image: nginx
      resources:
        limits:
          memory: "1Gi"
```

Apply:

```bash
kubectl apply -f invalid-pod.yaml
```

Expected result: admission is rejected because the memory limit exceeds the configured maximum of `512Mi`.

### Step 9: Clean up

Delete the namespace and all resources created inside it:

```bash
kubectl delete namespace resource-demo
```

---

## 13. Common Troubleshooting Scenarios

### Scenario 1: Pod is Pending

Check:

```bash
kubectl describe pod <pod-name> -n <namespace>
```

Possible reason: available nodes do not have enough allocatable CPU or memory to satisfy the Pod's requests.

### Scenario 2: Pod creation fails with a quota error

Check:

```bash
kubectl describe resourcequota -n <namespace>
```

Possible reason: the new Pod would exceed the namespace's configured quota.

### Scenario 3: Pod creation fails due to LimitRange

Check:

```bash
kubectl describe limitrange -n <namespace>
```

Possible reason: the requested CPU or memory is outside the configured minimum or maximum.

### Scenario 4: Container shows OOMKilled

Check:

```bash
kubectl describe pod <pod-name> -n <namespace>
```

Possible reason: the container exceeded its memory limit or was terminated by the out-of-memory mechanism.

### Scenario 5: CPU usage is lower than expected

Check the container's CPU limit and actual usage:

```bash
kubectl describe pod <pod-name> -n <namespace>
kubectl top pod <pod-name> -n <namespace>
```

Possible reason: the CPU limit is too restrictive, causing throttling.

---

## 14. Quick Revision

| Topic | Remember this |
|---|---|
| Request | Used for scheduling decisions |
| Limit | Restricts container resource usage |
| LimitRange | Sets defaults and bounds for individual resources in a namespace |
| ResourceQuota | Controls total resource consumption in a namespace |
| Guaranteed | Every container has matching CPU and memory requests and limits |
| Burstable | Some CPU or memory resource setting exists, but the Pod is not Guaranteed |
| BestEffort | No CPU or memory requests or limits are configured |
| `kubectl describe pod` | Checks resource settings and Pod events |
| `kubectl describe limitrange` | Checks default and permitted resource values |
| `kubectl describe resourcequota` | Checks aggregate usage and quota limits |
| `kubectl top pods` | Checks actual resource usage when Metrics Server is available |

---

## 15. Interview Questions

### Q1. What is the difference between requests and limits?

Requests help Kubernetes schedule a Pod, while limits restrict how much CPU or memory a container can use.

### Q2. What is LimitRange?

LimitRange defines default, minimum, and maximum resource settings for containers or Pods within a namespace.

### Q3. What is ResourceQuota?

ResourceQuota limits aggregate consumption of resources or the number of supported objects within a namespace.

### Q4. What is the difference between LimitRange and ResourceQuota?

LimitRange controls individual resource settings, whereas ResourceQuota controls namespace-wide totals.

### Q5. What happens when a container exceeds its CPU limit?

CPU usage is throttled.

### Q6. What happens when a container exceeds its memory limit?

The container may be terminated by the OOM killer, and its status may show `OOMKilled`.

### Q7. What are the three Kubernetes QoS classes?

Guaranteed, Burstable, and BestEffort.

### Q8. Can LimitRange and ResourceQuota be used together?

Yes. They can enforce individual resource rules and namespace-wide resource budgets at the same time.

### Q9. At which level are requests and limits defined?

They are defined at the container level inside the Pod specification.

### Q10. How do you check a namespace's quota usage?

```bash
kubectl describe resourcequota -n <namespace>
```

### Q11. Can a Pod have Guaranteed QoS if its CPU requests equal its limits but its memory requests do not equal its limits?

No. For Guaranteed QoS, every container must have both CPU and memory requests equal to their respective limits.

### Q12. Does ResourceQuota automatically assign default requests and limits?

No. LimitRange can supply default requests and limits. ResourceQuota controls aggregate consumption.

---

## 16. Final Concept to Remember

Think of Kubernetes resource management as three levels of control:

1. **Requests and Limits:** How much CPU and memory a container requests and is allowed to consume.
2. **LimitRange:** What resource settings are permitted for individual workloads in a namespace.
3. **ResourceQuota:** How much total resource consumption the namespace is allowed.

Finally, **QoS** is the class Kubernetes assigns to a Pod based on its resource configuration.

These concepts work together to improve scheduling, resource utilization, and workload isolation in a Kubernetes cluster.
