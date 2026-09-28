# Kubernetes Deployment: Complete Step-by-Step Process

**Date:** September 28, 2026

## Question

Suppose a user applies a `deployment.yaml` file using
`kubectl apply -f deployment.yaml`. Explain the complete step-by-step
process of how Kubernetes creates a Deployment, ReplicaSet, and Pods,
assigns them to Worker Nodes, and makes the application ready to serve
traffic. Explain the role of etcd and other Kubernetes components in
this process.

## Answer

### Step 1: User Applies the Deployment YAML

The user executes:

``` bash
kubectl apply -f deployment.yaml
```

-   `kubectl` reads the YAML file and sends the Deployment configuration
    to the Kubernetes API Server (`kube-apiserver`).

**Result:** The Deployment request reaches the API Server.

### Step 2: API Server Processes the Request

The API Server performs the following operations:

1.  **Authentication:** Verifies the identity of the user.
2.  **Authorization:** Checks whether the user has permission to create
    or update the Deployment.
3.  **Admission Control:** Applies configured admission policies and
    checks.
4.  **Validation:** Validates the resource configuration.

If the request is accepted, the API Server processes the Deployment
object for persistence.

**Result:** The Deployment request is successfully processed.

### Step 3: etcd Stores the Deployment Object

-   The API Server stores the Deployment object in **etcd**, Kubernetes'
    persistent key-value store.
-   The Deployment object contains the desired state, including the
    replica count, Pod template, and container image.

**Result:** The Deployment object is persisted in etcd.

### Step 4: Deployment Controller Creates a ReplicaSet

-   The Deployment Controller, running inside `kube-controller-manager`,
    detects the new Deployment through the API Server.
-   It compares the desired state with the current state.
-   It creates a ReplicaSet through the API Server.

**Result:** The ReplicaSet is created to maintain the desired number of
Pods.

### Step 5: ReplicaSet Controller Creates Pods

-   The ReplicaSet Controller, also running inside
    `kube-controller-manager`, detects the new ReplicaSet.
-   It compares the desired replica count with the actual number of
    matching Pods.
-   It creates the required Pod objects through the API Server.

For example, if the Deployment specifies three replicas and no matching
Pods exist, the ReplicaSet Controller creates three Pod objects.

**Result:** The required Pod objects are created and await scheduling.

### Step 6: Scheduler Assigns Pods to Worker Nodes

-   The `kube-scheduler` detects Pods that do not have a Worker Node
    assigned.
-   It evaluates eligible Worker Nodes based on resource availability,
    scheduling constraints, affinity rules, taints, and tolerations.
-   It selects a suitable Worker Node for each Pod.
-   It records the node assignment through the API Server.

**Result:** Each Pod is assigned to a suitable Worker Node.

### Step 7: Kubelet Detects the Assigned Pods

-   The Kubelet, running on each Worker Node, watches the API Server for
    Pods assigned to its node.
-   It detects the newly assigned Pods and reads their specifications.
-   It coordinates with the container runtime to ensure that the
    required containers are created and running.

**Result:** The Kubelet begins preparing the Pods on the assigned Worker
Nodes.

### Step 8: Container Runtime Pulls the Image and Starts Containers

-   The Kubelet communicates with the container runtime through the
    Container Runtime Interface (CRI).
-   The runtime pulls the required container image if it is not already
    available locally.
-   It creates and starts the containers according to the Pod
    specification.

Examples of container runtimes include **containerd and CRI-O**.

**Result:** The application containers start running inside the Pods.

### Step 9: CNI Plugin Configures Pod Networking

-   The Container Network Interface (CNI) plugin configures Pod
    networking according to the cluster's networking setup.
-   It assigns Pod IP addresses and establishes network connectivity.

**Result:** The Pods receive network connectivity and can communicate
with other permitted endpoints.

### Step 10: Kubelet Performs Health Checks

The Kubelet monitors the containers and executes configured health
probes:

-   **Startup Probe:** Checks whether the application has started.
-   **Liveness Probe:** Checks whether the container needs to be
    restarted.
-   **Readiness Probe:** Checks whether the application is ready to
    receive traffic.

When the readiness conditions are satisfied, the Pod is marked Ready.

**Result:** The Pod becomes Ready to receive traffic.

### Step 11: Service and EndpointSlice Make the Application Reachable

If a Kubernetes Service is configured:

-   The Service provides a stable network endpoint for accessing the
    application.
-   The EndpointSlice Controller maintains EndpointSlices containing the
    Service's backend endpoints.
-   Ready Pods are normally included as eligible endpoints, depending on
    the Service configuration.
-   `kube-proxy`, when used, maintains network rules to route Service
    traffic to eligible Pod endpoints.

For external access, an Ingress or Gateway and its corresponding
controller may also be configured.

**Result:** Traffic can reach the application through the configured
Service or external access mechanism.

### Step 12: Deployment Reaches the Desired State

-   The Deployment Controller continuously monitors the Deployment and
    its ReplicaSet.
-   Kubernetes works toward maintaining the desired number of replicas.
-   Once the required Pods are available, the Deployment reports the
    corresponding status.

For example, if the Deployment specifies three replicas, Kubernetes
works to maintain three Pods.

**Result:** The application is running, and its Ready Pods can serve
traffic.

## Complete Kubernetes Deployment Flow

``` text
User
  |
  | kubectl apply -f deployment.yaml
  v
API Server
  |
  | Authentication, Authorization,
  | Admission Control, Validation
  v
etcd
  |
  | Stores Deployment Object
  v
Deployment Controller
  |
  | Creates ReplicaSet
  v
ReplicaSet Controller
  |
  | Creates Pod Objects
  v
kube-scheduler
  |
  | Selects Suitable Worker Nodes
  v
Worker Nodes
  |
  v
Kubelet
  |
  | CRI
  v
Container Runtime
  |
  | Pulls Image and Starts Containers
  v
CNI Plugin
  |
  | Configures Pod Networking
  v
Application Containers Running
  |
  v
Kubelet Health Probes
  |
  | Readiness Probe Succeeds
  v
Pod Ready
  |
  v
Service / EndpointSlice
  |
  | kube-proxy (when used)
  v
Application Ready to Serve Traffic
```

## Role of etcd

**etcd is the persistent key-value store that maintains Kubernetes
cluster state.**

During the Deployment process:

-   The API Server stores the Deployment object in etcd.
-   The API Server also stores the ReplicaSet and Pod objects created by
    the controllers.
-   Updates to resource information, including Pod scheduling
    assignments, are persisted through the API Server.

**Important:** Controllers and the Scheduler communicate with the API
Server rather than directly accessing etcd.

## Kubernetes Components and Their Roles

  -----------------------------------------------------------------------
  Component                           Responsibility
  ----------------------------------- -----------------------------------
  `kubectl`                           Sends the Deployment configuration
                                      to the API Server.

  `kube-apiserver`                    Authenticates, authorizes,
                                      validates, and processes API
                                      requests.

  `etcd`                              Stores persistent Kubernetes
                                      cluster state.

  Deployment Controller               Creates and manages ReplicaSets.

  ReplicaSet Controller               Creates and maintains the required
                                      number of Pods.

  `kube-scheduler`                    Assigns Pods to suitable Worker
                                      Nodes.

  Kubelet                             Ensures assigned Pods and their
                                      containers are running.

  Container Runtime                   Pulls images and starts containers.

  CNI Plugin                          Configures Pod networking.

  Kubelet Probes                      Monitor application startup,
                                      liveness, and readiness.

  EndpointSlice Controller            Maintains Service backend endpoint
                                      information.

  `kube-proxy`                        Implements Service networking when
                                      used.
  -----------------------------------------------------------------------

## Final Interview Summary

When a user executes `kubectl apply -f deployment.yaml`, the API Server
authenticates, authorizes, and validates the request before storing the
Deployment object in etcd. The Deployment Controller creates a
ReplicaSet, and the ReplicaSet Controller creates the required Pod
objects.

The Scheduler assigns the Pods to suitable Worker Nodes. The Kubelet
detects the assigned Pods and works with the container runtime to start
the containers. The CNI plugin configures Pod networking, and the
Kubelet performs health checks.

Once the Pods become Ready, the Service and EndpointSlice mechanisms
make them eligible to receive traffic.

**The controllers continuously reconcile the actual state with the
desired state.**
