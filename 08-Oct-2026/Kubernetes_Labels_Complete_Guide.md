# Kubernetes Labels — Complete Learning, Demo & Hands-on Guide

## 1. What are Kubernetes Labels?

**Labels are key-value pairs attached to Kubernetes objects** such as Pods, Nodes, Deployments, Services, ReplicaSets, StatefulSets, and other resources.

A label looks like:

```yaml
labels:
  app: nginx
  environment: production
  team: platform
```

Here:

- `app` → label key
- `nginx` → label value
- `environment` → another label key
- `production` → its value

Labels are primarily used to **identify, organize, select, and group Kubernetes resources**.

> **Important:** A label does not change the actual behavior of a resource by itself. It provides metadata that Kubernetes and users can use for selection and organization.

---

# 2. Why Do We Need Labels?

Imagine a Kubernetes cluster has hundreds of Pods:

```text
nginx-1
nginx-2
nginx-3
payment-1
payment-2
order-1
order-2
user-1
user-2
```

Without labels, it becomes difficult to answer questions such as:

- Which Pods belong to the payment application?
- Which Pods are running in production?
- Which Pods belong to version `v2`?
- Which Nodes are GPU-enabled?
- Which Pods should a Service send traffic to?
- Which Pods should a Deployment manage?
- Which resources belong to a particular team?

Labels solve this problem.

For example:

```yaml
labels:
  app: payment
  environment: production
  version: v2
```

Now we can easily select the required resources.

---

# 3. Why Are Labels Important?

Labels are one of the most important concepts in Kubernetes because they are used for **resource selection and grouping**.

## Major use cases

### 3.1 Resource Identification

We can identify resources based on application, environment, version, team, etc.

```bash
kubectl get pods -l app=payment
```

---

### 3.2 Service-to-Pod Communication

A Kubernetes Service uses a **selector** to identify the Pods to which it should send traffic.

Example:

```yaml
selector:
  app: nginx
```

The Service selects Pods having:

```yaml
labels:
  app: nginx
```

This is a very important real-world use of labels.

---

### 3.3 Deployment/Controller Management

Controllers such as Deployments use labels and selectors to identify the Pods they manage.

Example:

```yaml
selector:
  matchLabels:
    app: nginx
```

Pods:

```yaml
labels:
  app: nginx
```

The selector and labels must match correctly.

---

### 3.4 Node Selection

Labels can be attached to Nodes.

Example:

```text
disk=ssd
environment=production
gpu=true
```

Pods can then request specific Nodes using mechanisms such as:

- `nodeSelector`
- node affinity

Example:

```yaml
nodeSelector:
  environment: production
```

---

### 3.5 Environment Separation

Common labels:

```text
environment=dev
environment=qa
environment=uat
environment=prod
```

Then:

```bash
kubectl get pods -l environment=prod
```

---

### 3.6 Version Selection

Example:

```text
version=v1
version=v2
```

Then:

```bash
kubectl get pods -l version=v2
```

This is useful in rolling deployments, blue/green deployments, and canary-style architectures.

---

# 4. Labels vs Annotations

This is a common interview question.

## Labels

Labels are designed for **selection and grouping**.

Example:

```yaml
labels:
  app: nginx
  environment: prod
```

We can use:

```bash
kubectl get pods -l app=nginx
```

## Annotations

Annotations are generally used to store **additional metadata that is not intended for selection**.

Example:

```yaml
annotations:
  description: "Production NGINX application"
  owner: "platform-team"
```

### Interview answer

> Labels are used to identify, group, and select Kubernetes resources, while annotations are used to store additional metadata that is not normally used for selecting resources.

---

# 5. Common Kubernetes Resources Where We Use Labels

Labels can be applied to many Kubernetes resources:

```text
Pod
Deployment
ReplicaSet
StatefulSet
DaemonSet
Service
Node
Namespace
ConfigMap
Secret
Job
CronJob
```

For today's hands-on session, we will focus on:

1. Pod labels
2. Controller/Deployment labels
3. Node labels
4. Service labels and selectors

---

# 6. Pod Labels

A Pod can have one or more labels.

Example:

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: nginx-pod
  labels:
    app: nginx
    environment: dev
    version: v1
spec:
  containers:
    - name: nginx
      image: nginx:latest
```

Create it:

```bash
kubectl apply -f nginx-pod.yaml
```

Check the labels:

```bash
kubectl get pod nginx-pod --show-labels
```

Example:

```text
NAME        READY   STATUS    LABELS
nginx-pod   1/1     Running   app=nginx,environment=dev,version=v1
```

---

# 7. Get Labels of Pods

```bash
kubectl get pods --show-labels
```

Get labels for a specific Pod:

```bash
kubectl get pod nginx-pod --show-labels
```

Using wide output:

```bash
kubectl get pods -o wide
```

Inspect complete details:

```bash
kubectl describe pod nginx-pod
```

---

# 8. Apply a Label to an Existing Pod

Suppose the Pod already exists.

Add:

```text
team=platform
```

Command:

```bash
kubectl label pod nginx-pod team=platform
```

Verify:

```bash
kubectl get pod nginx-pod --show-labels
```

---

# 9. Update an Existing Label

Suppose:

```text
environment=dev
```

We want:

```text
environment=prod
```

Use:

```bash
kubectl label pod nginx-pod environment=prod --overwrite
```

Verify:

```bash
kubectl get pod nginx-pod --show-labels
```

> `--overwrite` is required when you want to change an existing label value.

---

# 10. Remove a Label

To remove a label, put a `-` after the label key:

```bash
kubectl label pod nginx-pod team-
```

Verify:

```bash
kubectl get pod nginx-pod --show-labels
```

---

# 11. Get Pods Using Labels

This is called a **label selector**.

### Equality selector

```bash
kubectl get pods -l app=nginx
```

Equivalent syntax:

```bash
kubectl get pods --selector=app=nginx
```

### Multiple labels

```bash
kubectl get pods -l app=nginx,environment=prod
```

This means:

```text
app must be nginx
AND
environment must be prod
```

---

# 12. Label Selectors

Kubernetes supports several selector expressions.

## Equality

```bash
kubectl get pods -l app=nginx
```

## Not equal

```bash
kubectl get pods -l 'environment!=prod'
```

## Set-based: In

```bash
kubectl get pods -l 'environment in (dev,qa)'
```

## Set-based: Not In

```bash
kubectl get pods -l 'environment notin (prod,uat)'
```

## Exists

```bash
kubectl get pods -l team
```

This selects Pods that have a `team` label.

## Does not exist

```bash
kubectl get pods -l '!team'
```

This selects Pods that do not have the `team` label.

---

# 13. Get Other Resources Using Labels

Labels are not limited to Pods.

Examples:

```bash
kubectl get deployments -l app=nginx
```

```bash
kubectl get services -l app=nginx
```

```bash
kubectl get nodes -l environment=prod
```

```bash
kubectl get all -l app=nginx
```

> `kubectl get all` is a convenient view of common workload-related resources, but it does not literally mean every Kubernetes API resource.

---

# 14. Controller Labels — Deployment Example

A Deployment normally contains labels at more than one level.

Example:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nginx-deployment
  labels:
    app: nginx
    component: frontend

spec:
  replicas: 3

  selector:
    matchLabels:
      app: nginx

  template:
    metadata:
      labels:
        app: nginx
        component: frontend

    spec:
      containers:
        - name: nginx
          image: nginx:1.27
          ports:
            - containerPort: 80
```

There are two important areas.

## Deployment metadata labels

```yaml
metadata:
  labels:
    app: nginx
```

These labels belong to the Deployment object itself.

## Pod template labels

```yaml
template:
  metadata:
    labels:
      app: nginx
```

These labels are applied to Pods created by the Deployment.

## Deployment selector

```yaml
selector:
  matchLabels:
    app: nginx
```

The Deployment uses this selector to identify the Pods belonging to it.

---

# 15. Very Important Controller Concept

Remember this relationship:

```text
Deployment
    |
    | selector
    v
Pod labels
```

For example:

```text
Deployment selector:
app=nginx

        ↓

Pod labels:
app=nginx
```

The selector must correctly match the Pod template labels.

For a Deployment:

```yaml
spec:
  selector:
    matchLabels:
      app: nginx

  template:
    metadata:
      labels:
        app: nginx
```

If these do not match appropriately, the Deployment definition will be rejected or the intended controller behavior will not work correctly.

---

# 16. Hands-on: Create Deployment

Create:

```bash
kubectl create deployment nginx-deployment --image=nginx:1.27 --replicas=3
```

Check:

```bash
kubectl get deployment
```

```bash
kubectl get pods --show-labels
```

Inspect:

```bash
kubectl describe deployment nginx-deployment
```

Get Pods using the Deployment's label:

```bash
kubectl get pods -l app=nginx
```

---

# 17. Apply Labels to a Deployment

Add a label:

```bash
kubectl label deployment nginx-deployment environment=dev
```

Verify:

```bash
kubectl get deployment --show-labels
```

Remove it:

```bash
kubectl label deployment nginx-deployment environment-
```

---

# 18. Important: Deployment Label vs Pod Label

This is a common practical confusion.

If you run:

```bash
kubectl label deployment nginx-deployment environment=prod
```

you are labeling the **Deployment object**.

You are NOT automatically adding the same label to existing Pods.

To make Pods have the label, the label should be added to the Deployment's Pod template.

For example:

```yaml
spec:
  template:
    metadata:
      labels:
        app: nginx
        environment: prod
```

When the Pod template changes, the Deployment creates a new ReplicaSet and performs a rollout.

---

# 19. Node Labels

Nodes can also have labels.

Check Node labels:

```bash
kubectl get nodes --show-labels
```

For a specific Node:

```bash
kubectl get node <node-name> --show-labels
```

---

# 20. Apply a Label to a Node

Example:

```bash
kubectl label node <node-name> environment=prod
```

Verify:

```bash
kubectl get nodes --show-labels
```

Or:

```bash
kubectl get nodes -l environment=prod
```

---

# 21. Update a Node Label

```bash
kubectl label node <node-name> environment=dev --overwrite
```

---

# 22. Remove a Node Label

```bash
kubectl label node <node-name> environment-
```

---

# 23. Node Labels and nodeSelector

One of the most useful applications of Node labels is selecting where a Pod should run.

Suppose the Node has:

```text
environment=prod
```

Pod:

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: nginx-prod
spec:
  nodeSelector:
    environment: prod

  containers:
    - name: nginx
      image: nginx:1.27
```

The scheduler will look for a Node with:

```text
environment=prod
```

This gives us a simple flow:

```text
Node
  |
  | label
  v
environment=prod
  |
  | nodeSelector
  v
Pod
```

---

# 24. Practical Node Label Demo

Find your Nodes:

```bash
kubectl get nodes
```

Choose a Node:

```bash
kubectl get nodes
```

Add a label:

```bash
kubectl label node <node-name> workload=app
```

Verify:

```bash
kubectl get nodes -l workload=app
```

Create a Pod:

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: nginx-node-label
spec:
  nodeSelector:
    workload: app
  containers:
    - name: nginx
      image: nginx:1.27
```

Apply:

```bash
kubectl apply -f nginx-node-label.yaml
```

Check where it was scheduled:

```bash
kubectl get pod nginx-node-label -o wide
```

The Pod should be scheduled on a Node matching:

```text
workload=app
```

---

# 25. Service Labels vs Service Selectors

This distinction is extremely important.

A Service itself can have labels:

```yaml
metadata:
  labels:
    app: nginx
    component: frontend
```

But the Service's **selector** determines which Pods receive traffic:

```yaml
spec:
  selector:
    app: nginx
```

So:

```text
Service label
    ↓
Identifies the Service object

Service selector
    ↓
Selects backend Pods
```

Do not confuse these two concepts.

---

# 26. Service Example

Example:

```yaml
apiVersion: v1
kind: Service
metadata:
  name: nginx-service
  labels:
    app: nginx
    component: frontend

spec:
  selector:
    app: nginx

  ports:
    - port: 80
      targetPort: 80

  type: ClusterIP
```

Here:

### Service label

```yaml
metadata:
  labels:
    app: nginx
```

This labels the Service object.

### Service selector

```yaml
selector:
  app: nginx
```

This selects Pods having:

```yaml
labels:
  app: nginx
```

---

# 27. Service Hands-on Demo

First check your Pods:

```bash
kubectl get pods --show-labels
```

Suppose:

```text
nginx-pod-1   app=nginx
nginx-pod-2   app=nginx
nginx-pod-3   app=nginx
```

Create Service:

```bash
kubectl expose deployment nginx-deployment \
  --name=nginx-service \
  --port=80 \
  --target-port=80
```

Check:

```bash
kubectl get svc
```

Check Service labels:

```bash
kubectl get svc nginx-service --show-labels
```

Check Service selector:

```bash
kubectl describe svc nginx-service
```

Look for:

```text
Selector: app=nginx
```

---

# 28. Check Which Pods Are Selected by a Service

If the Service selector is:

```text
app=nginx
```

Run:

```bash
kubectl get pods -l app=nginx
```

Then check endpoints:

```bash
kubectl get endpoints nginx-service
```

On newer Kubernetes versions, you can also inspect EndpointSlices:

```bash
kubectl get endpointslice
```

This helps demonstrate that the Service is discovering backend Pods based on labels/selectors.

---

# 29. What Happens If Service Selector Does Not Match?

Suppose Pods have:

```text
app=nginx
```

But Service has:

```yaml
selector:
  app: apache
```

Then:

```text
Service
   |
   | selector app=apache
   |
   X
   |
Pods
   app=nginx
```

No matching Pods will be selected.

As a result, the Service will have no normal backend endpoints.

This is one of the most common Kubernetes troubleshooting scenarios.

---

# 30. Troubleshooting Service Using Labels

Check Service:

```bash
kubectl get svc nginx-service -o yaml
```

Check selector:

```bash
kubectl describe svc nginx-service
```

Check Pods:

```bash
kubectl get pods --show-labels
```

Check matching Pods:

```bash
kubectl get pods -l app=nginx
```

Check EndpointSlices:

```bash
kubectl get endpointslice
```

If the selector and Pod labels do not match, investigate the labels first.

---

# 31. Labels on ReplicaSets

Deployments create ReplicaSets.

Check:

```bash
kubectl get rs --show-labels
```

Inspect:

```bash
kubectl describe rs <replicaset-name>
```

You will commonly see labels such as:

```text
app=nginx
pod-template-hash=xxxxx
```

The `pod-template-hash` label is used by Deployments to distinguish ReplicaSets associated with different Pod templates.

---

# 32. Controller Hierarchy

A useful mental model:

```text
Deployment
    |
    v
ReplicaSet
    |
    v
Pods
```

Labels and selectors help controllers identify the resources they manage.

Example:

```text
Deployment selector
        |
        v
ReplicaSet / Pod labels
        |
        v
Pods
```

The exact selector relationships vary by controller, but the central concept is that **selectors identify the resources a controller is responsible for**.

---

# 33. View Labels in YAML

For a Pod:

```bash
kubectl get pod nginx-pod -o yaml
```

Look for:

```yaml
metadata:
  labels:
```

For a Deployment:

```bash
kubectl get deployment nginx-deployment -o yaml
```

Look at:

```yaml
metadata:
  labels:
```

and:

```yaml
spec:
  template:
    metadata:
      labels:
```

For a Node:

```bash
kubectl get node <node-name> -o yaml
```

For a Service:

```bash
kubectl get svc nginx-service -o yaml
```

---

# 34. Add Multiple Labels

You can add multiple labels in one command:

```bash
kubectl label pod nginx-pod environment=prod team=platform version=v2
```

Verify:

```bash
kubectl get pod nginx-pod --show-labels
```

---

# 35. Remove Multiple Labels

```bash
kubectl label pod nginx-pod environment- team- version-
```

---

# 36. Get All Pods With a Specific Label

```bash
kubectl get pods -l environment=prod
```

Across all namespaces:

```bash
kubectl get pods -A -l environment=prod
```

This is very useful in production troubleshooting.

---

# 37. Get Multiple Resource Types Using a Label

```bash
kubectl get deployments,services,pods -l app=nginx
```

You can also use:

```bash
kubectl get all -l app=nginx
```

Remember that `all` is only a convenient collection of common resources, not literally every Kubernetes object.

---

# 38. Delete Resources Using Labels

Labels can also be used with delete operations.

Example:

```bash
kubectl delete pods -l app=nginx
```

Or:

```bash
kubectl delete pods -l environment=dev
```

**Production caution:** Always verify the selected resources before executing destructive commands.

First:

```bash
kubectl get pods -l environment=dev
```

Then delete if you are sure:

```bash
kubectl delete pods -l environment=dev
```

---

# 39. Label-Based Rollout and Operational Workflows

Labels are commonly used in operational workflows to:

- identify workloads
- filter resources
- troubleshoot applications
- select Service backends
- select Nodes
- separate environments
- identify versions
- organize ownership
- automate operational tasks

Example:

```text
app=payment
environment=prod
version=v2
team=payments
```

Then:

```bash
kubectl get pods -l app=payment
```

or:

```bash
kubectl get pods -l 'environment=prod,team=payments'
```

---

# 40. Recommended Label Strategy

A production organization should use a consistent labeling strategy.

A useful set of labels:

```yaml
labels:
  app.kubernetes.io/name: payment
  app.kubernetes.io/instance: payment-prod
  app.kubernetes.io/version: "2.0"
  app.kubernetes.io/component: api
  app.kubernetes.io/part-of: ecommerce
  app.kubernetes.io/managed-by: helm
```

Kubernetes provides the `app.kubernetes.io/*` recommended label convention for common application metadata.

---

# 41. Real-World Example

Imagine an e-commerce platform:

```text
payment
order
user
frontend
```

Production payment Pods:

```yaml
labels:
  app: payment
  environment: prod
  version: v2
  team: payments
```

Now operations can run:

```bash
kubectl get pods -l app=payment
```

Production only:

```bash
kubectl get pods -l 'app=payment,environment=prod'
```

Version v2 only:

```bash
kubectl get pods -l 'app=payment,version=v2'
```

Payment team workloads:

```bash
kubectl get pods -l team=payments
```

This is why labels become extremely powerful in large clusters.

---

# 42. Complete Hands-on Lab

## Step 1 — Create Namespace

```bash
kubectl create namespace label-demo
```

---

## Step 2 — Create Deployment

Create `nginx-label-demo.yaml`:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nginx
  namespace: label-demo
  labels:
    app: nginx
    environment: dev
    team: platform

spec:
  replicas: 3

  selector:
    matchLabels:
      app: nginx

  template:
    metadata:
      labels:
        app: nginx
        environment: dev
        version: v1
        team: platform

    spec:
      containers:
        - name: nginx
          image: nginx:1.27
          ports:
            - containerPort: 80
```

Apply:

```bash
kubectl apply -f nginx-label-demo.yaml
```

---

## Step 3 — Check Deployment

```bash
kubectl get deployment -n label-demo --show-labels
```

---

## Step 4 — Check Pods

```bash
kubectl get pods -n label-demo --show-labels
```

Expected conceptually:

```text
NAME                     LABELS
nginx-xxxxx-xxxxx        app=nginx,environment=dev,version=v1,team=platform
```

---

## Step 5 — Query Using Labels

```bash
kubectl get pods -n label-demo -l app=nginx
```

```bash
kubectl get pods -n label-demo -l environment=dev
```

```bash
kubectl get pods -n label-demo -l version=v1
```

```bash
kubectl get pods -n label-demo -l team=platform
```

---

## Step 6 — Add a Label

```bash
kubectl label pod -n label-demo <pod-name> temporary=true
```

Verify:

```bash
kubectl get pods -n label-demo --show-labels
```

---

## Step 7 — Remove the Label

```bash
kubectl label pod -n label-demo <pod-name> temporary-
```

---

## Step 8 — Change a Label

```bash
kubectl label pod -n label-demo <pod-name> environment=qa --overwrite
```

Verify:

```bash
kubectl get pod -n label-demo <pod-name> --show-labels
```

---

## Step 9 — Create a Service

```bash
kubectl expose deployment nginx \
  -n label-demo \
  --name=nginx-service \
  --port=80 \
  --target-port=80
```

Check:

```bash
kubectl get svc -n label-demo
```

---

## Step 10 — Verify Service Selector

```bash
kubectl describe svc nginx-service -n label-demo
```

You should see a selector similar to:

```text
Selector: app=nginx
```

---

## Step 11 — Verify Backend Pods

```bash
kubectl get pods -n label-demo -l app=nginx
```

Then:

```bash
kubectl get endpointslice -n label-demo
```

---

# 43. Node Label Hands-on

List Nodes:

```bash
kubectl get nodes
```

Add a label:

```bash
kubectl label node <node-name> workload=nginx
```

Verify:

```bash
kubectl get nodes --show-labels
```

Query:

```bash
kubectl get nodes -l workload=nginx
```

Remove:

```bash
kubectl label node <node-name> workload-
```

---

# 44. Important Production Caution

Be careful when changing labels used by controllers.

For example, changing a label that a Service uses as its selector can immediately change which Pods receive traffic.

Similarly, changing labels involved in controller selection can cause unexpected behavior.

Before changing a production label:

```bash
kubectl get pods --show-labels
kubectl get svc
kubectl describe svc <service-name>
kubectl describe deployment <deployment-name>
```

Understand the selector relationship first.

---

# 45. Useful Label Commands Cheat Sheet

## View labels

```bash
kubectl get pods --show-labels
```

```bash
kubectl get nodes --show-labels
```

```bash
kubectl get deployment --show-labels
```

```bash
kubectl get svc --show-labels
```

## Add label

```bash
kubectl label pod <pod> key=value
```

```bash
kubectl label node <node> key=value
```

```bash
kubectl label deployment <deployment> key=value
```

## Update label

```bash
kubectl label pod <pod> key=newvalue --overwrite
```

## Remove label

```bash
kubectl label pod <pod> key-
```

## Select resources

```bash
kubectl get pods -l key=value
```

```bash
kubectl get nodes -l key=value
```

```bash
kubectl get deployments -l key=value
```

```bash
kubectl get svc -l key=value
```

## Multiple labels

```bash
kubectl get pods -l key1=value1,key2=value2
```

## Set-based selector

```bash
kubectl get pods -l 'environment in (dev,qa)'
```

```bash
kubectl get pods -l 'environment notin (prod,uat)'
```

## Across namespaces

```bash
kubectl get pods -A -l app=nginx
```

---

# 46. Interview Questions

## Q1. What are labels in Kubernetes?

**Answer:**

> Labels are key-value pairs attached to Kubernetes resources. They are used to identify, organize, group, and select resources.

---

## Q2. Why are labels important?

**Answer:**

> Labels are important because Kubernetes uses selectors based on labels to identify resources. Services use selectors to find backend Pods, controllers use selectors to manage workloads, and labels are also used for filtering, organization, and Node selection.

---

## Q3. How do you add a label to a Pod?

```bash
kubectl label pod nginx-pod app=nginx
```

---

## Q4. How do you remove a label?

```bash
kubectl label pod nginx-pod app-
```

---

## Q5. How do you update an existing label?

```bash
kubectl label pod nginx-pod environment=prod --overwrite
```

---

## Q6. How do you get Pods with a particular label?

```bash
kubectl get pods -l app=nginx
```

---

## Q7. How does a Service find Pods?

**Answer:**

> A Service uses a label selector. It selects Pods whose labels match the Service selector.

Example:

```yaml
selector:
  app: nginx
```

Pods:

```yaml
labels:
  app: nginx
```

---

## Q8. What happens if Service selector does not match Pod labels?

**Answer:**

> The Service will not select those Pods, so they will not appear as normal Service backends.

---

## Q9. What is the difference between a Service label and Service selector?

**Answer:**

> A Service label identifies and categorizes the Service object itself. A Service selector identifies the backend Pods that should receive traffic.

---

## Q10. What is the difference between Deployment labels and Pod labels?

**Answer:**

> Labels under Deployment `metadata` belong to the Deployment object. Labels under `spec.template.metadata` are applied to the Pods created by the Deployment.

---

## Q11. What is the difference between labels and annotations?

**Answer:**

> Labels are intended for identifying and selecting resources. Annotations store additional metadata and are generally not used for resource selection.

---

## Q12. How are Node labels useful?

**Answer:**

> Node labels allow us to classify Nodes and control Pod placement using mechanisms such as `nodeSelector` and node affinity.

---

# 47. Simple Architecture to Explain During Your Session

Use this diagram verbally:

```text
                 Kubernetes Cluster
                        |
        +---------------+---------------+
        |               |               |
      Node            Node            Node
   environment=    environment=    environment=
      prod             dev             prod
        |
        |
       Pod
   app=payment
   version=v2
        |
        |
   +---------+
   | Service |
   | selector|
   |app=payment
   +---------+
        |
        v
   Matching Pods
```

The key message:

```text
LABEL
  ↓
Identifies resource

SELECTOR
  ↓
Finds matching resources

CONTROLLER / SERVICE / SCHEDULER
  ↓
Uses that selection
```

---

# 48. Final Session Summary

The most important points to remember:

1. **Labels are key-value pairs.**
2. Labels help us **identify and organize resources**.
3. Labels become powerful when used with **selectors**.
4. A Service uses a selector to find backend Pods.
5. Controllers use selectors to identify workloads they manage.
6. Node labels can be used with `nodeSelector` and affinity.
7. `--show-labels` helps us inspect labels.
8. `-l` / `--selector` helps us filter resources.
9. `--overwrite` is used to change an existing label.
10. `key-` removes a label.
11. Service labels and Service selectors are different concepts.
12. Deployment labels and Pod-template labels are different concepts.
13. Always check selector relationships before changing production labels.

---

# 49. Suggested Live Demo Flow

For a smooth training session, demonstrate in this order:

```text
1. Explain what labels are
        ↓
2. Explain why labels are required
        ↓
3. Create Deployment
        ↓
4. Show Pod labels
        ↓
5. Add Pod label
        ↓
6. Update Pod label
        ↓
7. Remove Pod label
        ↓
8. Filter Pods using -l
        ↓
9. Explain Deployment selector
        ↓
10. Explain Pod template labels
        ↓
11. Add Node label
        ↓
12. Use nodeSelector
        ↓
13. Create Service
        ↓
14. Explain Service selector
        ↓
15. Show matching Pods
        ↓
16. Show EndpointSlices
        ↓
17. Demonstrate selector mismatch
        ↓
18. Troubleshoot the mismatch
        ↓
19. Finish with interview questions
```

## One-line takeaway

> **Labels identify Kubernetes resources, while selectors use those labels to find and group the resources that Kubernetes components need to work with.**
