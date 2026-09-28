# Kubernetes Fundamentals: Concepts, Architecture, Components, and Deployment Options

**Date:** 28 September 2026

## 1. What Is Kubernetes?

**Kubernetes (K8s)** is an open-source container orchestration platform
that automates the deployment, scheduling, scaling, networking, and
management of containerized applications across a cluster of machines.

It helps teams run applications reliably by maintaining the desired
state declared by users.

### In simple terms

Docker can package and run a container. Kubernetes coordinates many
containers across multiple machines and helps keep applications
available, scalable, and manageable.

### Key capabilities

-   Container orchestration and scheduling
-   Declarative configuration and desired-state management
-   Self-healing: restarting containers and replacing failed Pods
-   Horizontal scaling
-   Service discovery and load balancing
-   Rolling updates and rollbacks
-   Configuration and secret management
-   Storage orchestration
-   Extensibility through APIs and controllers

> Kubernetes does not build container images. A separate tool such as
> Docker or Buildah is typically used to build images.

## 2. History of Kubernetes

-   **Before Kubernetes:** Google developed internal
    container-management systems, including Borg, to operate workloads
    at large scale.
-   **2014:** Google announced Kubernetes as an open-source project,
    drawing on lessons from Borg.
-   **2015:** Kubernetes 1.0 was released, and the project was
    contributed to the newly formed Cloud Native Computing Foundation
    (CNCF).
-   **Today:** Kubernetes is a widely adopted open-source platform
    supported by a large ecosystem of cloud providers, vendors, and
    community contributors.

Kubernetes is often abbreviated as **K8s**: the "8" represents the eight
letters between "K" and "s."

## 3. Why Was Kubernetes Needed?

Running containers manually becomes difficult as application count,
traffic, and infrastructure grow.

### Challenges without an orchestrator

-   Manually placing containers on servers
-   Recovering from node or application failures
-   Scaling services as demand changes
-   Managing service-to-service communication and discovery
-   Performing safe application updates
-   Coordinating configuration, secrets, and persistent storage
-   Maintaining consistency across development, testing, and production

### What Kubernetes provides

Kubernetes lets teams describe the desired state---for example, "run
three replicas of this application"---and controllers continually work
to move the cluster toward that state.

## 4. Is Kubernetes Similar to Other Tools?

Yes. Several platforms address container orchestration or application
deployment, but they differ in architecture, operating model, and
ecosystem.

  -----------------------------------------------------------------------
  Platform / Tool         Main purpose            How it differs
  ----------------------- ----------------------- -----------------------
  **Docker Swarm**        Container orchestration Integrated with Docker;
                                                  generally simpler, with
                                                  a smaller ecosystem
                                                  than Kubernetes

  **Apache Mesos /        Cluster resource        General-purpose cluster
  Marathon**              management and workload management; a different
                          orchestration           architecture and
                                                  ecosystem

  **HashiCorp Nomad**     Workload orchestration  Can schedule containers
                                                  and non-containerized
                                                  workloads; different
                                                  operational model

  **OpenShift**           Kubernetes-based        Adds an integrated
                          application platform    enterprise platform,
                                                  developer workflows,
                                                  and security-oriented
                                                  defaults

  **Amazon ECS**          AWS container           AWS-native
                          orchestration service   orchestration; does not
                                                  expose the Kubernetes
                                                  API

  **Azure Container       Managed application     Higher-level
  Apps**                  platform for containers abstraction; users do
                                                  not manage a Kubernetes
                                                  cluster directly

  **Managed Kubernetes    Managed Kubernetes      Use Kubernetes while
  services**              control plane and       the cloud provider
                          related operations      operates selected
                                                  infrastructure
                                                  components
  -----------------------------------------------------------------------

These tools are not exact equivalents in every feature or use case. The
right choice depends on operational requirements, team skills,
portability, ecosystem, and platform constraints.

## 5. Kubernetes Cluster: High-Level Architecture

A Kubernetes **cluster** consists of a **control plane** and one or more
**worker nodes**.

-   **Control plane:** Makes cluster-wide decisions and manages the
    desired state.
-   **Worker nodes:** Run application workloads inside Pods.
-   **Add-ons:** Provide capabilities such as DNS, networking, metrics,
    and ingress.
-   **Container runtime:** Runs containers on each node.

``` text
                    Users / Administrators
                              |
                    kubectl / Kubernetes API
                              |
                    +----------------------+
                    |     CONTROL PLANE    |
                    |                      |
                    |  kube-apiserver      |
                    |  etcd                |
                    |  kube-scheduler      |
                    |  kube-controller-    |
                    |    manager           |
                    |  cloud-controller-   |
                    |    manager (optional)|
                    +----------+-----------+
                               |
                   Kubernetes API / control
                               |
          +--------------------+--------------------+
          |                                         |
  +-------v----------+                      +-------v----------+
  |  WORKER NODE 1   |                      |  WORKER NODE 2   |
  |                  |                      |                  |
  | kubelet          |                      | kubelet          |
  | kube-proxy*      |                      | kube-proxy*      |
  | container runtime|                      | container runtime|
  |                  |                      |                  |
  | Pods             |                      | Pods             |
  |  - containers    |                      |  - containers    |
  +------------------+                      +------------------+

* kube-proxy may be replaced by a CNI/network implementation in some clusters.
```

## 6. Control Plane

The control plane manages the cluster's overall state. In production
environments, it is commonly configured for high availability.

### 6.1 kube-apiserver

**Role:** The front end of the Kubernetes control plane.

Responsibilities: - Exposes the Kubernetes HTTP API. - Authenticates and
authorizes API requests. - Runs admission control and request
validation. - Reads and writes cluster state through the configured
storage layer. - Serves as the main communication hub for Kubernetes
components.

Most administrative tools and control-plane components communicate with
the cluster through the API server.

### 6.2 etcd

**Role:** A consistent, distributed key-value store used to persist
Kubernetes cluster state.

It stores information such as: - Kubernetes objects and their
specifications - Cluster configuration and metadata - State required for
recovery and coordination

Important points: - etcd is critical to cluster operation. - Backups and
restore procedures are essential. - Access should be tightly controlled
and data should be protected. - In a highly available setup, etcd
commonly runs as a cluster with an odd number of members.

### 6.3 kube-scheduler

**Role:** Selects a suitable worker node for each newly created,
unscheduled Pod.

It considers factors such as: - CPU and memory requests - Node selectors
and node affinity - Taints and tolerations - Pod affinity and
anti-affinity - Topology and scheduling constraints - Resource
availability and scheduling policies

The scheduler assigns a node to a Pod; it does not itself start the
container. The kubelet on the selected node handles that part.

### 6.4 kube-controller-manager

**Role:** Runs controller processes that continually compare the actual
cluster state with the desired state and take corrective action.

Examples of controllers: - **Node controller:** Detects and responds to
node conditions. - **Deployment / ReplicaSet-related controllers:** Help
maintain the requested number of Pod replicas. - **Job controller:**
Manages Jobs and their completion. - **EndpointSlice controller:**
Maintains EndpointSlices for Services. - **ServiceAccount controller:**
Supports ServiceAccount-related behavior.

Controllers generally work through the API server rather than directly
managing containers on nodes.

### 6.5 cloud-controller-manager (Cloud Environments)

**Role:** Integrates Kubernetes with a cloud provider's infrastructure
APIs.

Depending on the provider and configuration, it may manage: - Cloud node
information and lifecycle integration - Cloud routes - External load
balancers for Services - Provider-specific networking or infrastructure
integration

This component is optional and is mainly relevant to cloud-integrated
clusters. Its responsibilities vary by provider.

## 7. Worker Node (Data Plane)

Worker nodes provide the compute resources where application Pods run.

### 7.1 kubelet

**Role:** The node agent that ensures the containers described in Pod
specifications are running and healthy on that node.

Responsibilities: - Registers the node with the cluster. - Watches for
Pods assigned to the node. - Works with the container runtime through
the Container Runtime Interface (CRI). - Runs configured health probes
and reports status. - Mounts volumes and coordinates with storage
components. - Reports node and Pod status to the API server.

The kubelet does not schedule Pods; the scheduler selects the node.

### 7.2 Container Runtime

**Role:** Pulls container images and runs containers.

Examples include: - containerd - CRI-O

The runtime communicates with kubelet through the CRI. Docker Engine is
not the default Kubernetes runtime in modern clusters; Docker-built
images can still run when they conform to supported image formats.

### 7.3 kube-proxy

**Role:** Implements Kubernetes Service networking behavior on many
clusters, typically by programming network rules that direct traffic to
Service backends.

Key points: - Helps route traffic for ClusterIP and other Service
types. - Often uses iptables or IPVS, depending on configuration. - Some
cluster networking solutions replace kube-proxy functionality, so
kube-proxy is not universal.

### 7.4 Pods

A **Pod** is the smallest deployable unit in Kubernetes. It contains one
or more tightly coupled containers that share network identity and can
share storage volumes.

Key facts: - Containers in a Pod share the same IP address and port
space. - Containers in a Pod can communicate through `localhost`. - Pods
are generally disposable; controllers create replacements when needed. -
Each Pod receives its own network identity through the cluster
networking system.

### 7.5 CNI / Pod Networking

The **Container Network Interface (CNI)** is a standard used by
networking plugins to configure container network connectivity.

Examples of Kubernetes networking implementations include: - Calico -
Cilium - Flannel - Cloud-provider networking integrations

A CNI implementation typically provides Pod networking and may provide
NetworkPolicy enforcement, depending on the plugin and configuration.

## 8. Essential Kubernetes Objects and Workload Resources

  -----------------------------------------------------------------------
  Object                              Purpose
  ----------------------------------- -----------------------------------
  **Pod**                             Runs one or more containers

  **ReplicaSet**                      Maintains a specified number of Pod
                                      replicas

  **Deployment**                      Manages stateless application
                                      rollouts and ReplicaSets

  **StatefulSet**                     Manages workloads requiring stable
                                      identities and ordered behavior

  **DaemonSet**                       Runs a Pod on each selected node,
                                      or a subset of nodes

  **Job**                             Runs a task to completion

  **CronJob**                         Creates Jobs on a schedule

  **Service**                         Provides a stable network endpoint
                                      for a group of Pods

  **Ingress**                         Defines HTTP/HTTPS routing into a
                                      cluster when an Ingress controller
                                      is installed

  **Gateway API**                     A newer, extensible API for traffic
                                      routing, supported by compatible
                                      implementations

  **ConfigMap**                       Stores non-confidential
                                      configuration

  **Secret**                          Stores sensitive configuration
                                      data; encryption and access
                                      controls must be configured
                                      appropriately

  **PersistentVolume (PV)**           Represents cluster storage
                                      resources

  **PersistentVolumeClaim (PVC)**     A workload's request for storage

  **StorageClass**                    Defines classes and provisioning
                                      behavior for storage

  **Namespace**                       Organizes and scopes namespaced
                                      resources

  **ServiceAccount**                  Provides an identity for processes
                                      running in Pods

  **Role / ClusterRole**              Defines permissions for Kubernetes
                                      resources

  **RoleBinding /                     Grants roles to users, groups, or
  ClusterRoleBinding**                ServiceAccounts

  **NetworkPolicy**                   Defines allowed Pod network traffic
                                      when supported by the networking
                                      implementation
  -----------------------------------------------------------------------

## 9. Kubernetes Networking: Core Concepts

-   **Pod IP:** An IP address assigned to a Pod by the cluster
    networking implementation.
-   **ClusterIP Service:** Exposes a service internally within the
    cluster.
-   **NodePort Service:** Exposes a Service on a port on each node,
    subject to cluster configuration.
-   **LoadBalancer Service:** Requests an external load balancer when
    supported by the environment or integration.
-   **Ingress:** Provides HTTP/HTTPS routing rules; it requires an
    Ingress controller.
-   **DNS:** Cluster DNS, commonly CoreDNS, enables service-name
    resolution.
-   **NetworkPolicy:** Controls permitted network flows when the CNI
    supports enforcement.

## 10. Storage in Kubernetes

Kubernetes separates storage consumption from the underlying storage
implementation.

Typical flow: 1. An administrator or storage system defines a
StorageClass. 2. A workload requests storage through a
PersistentVolumeClaim (PVC). 3. Kubernetes binds the claim to an
existing PersistentVolume or dynamically provisions storage. 4. A Pod
mounts the claimed volume.

Common storage options include cloud block/file storage, network
storage, and local storage. The appropriate option depends on access
mode, performance, durability, and workload requirements.

## 11. Kubernetes Security and Access Control

Important security concepts: - **Authentication:** Establishes who or
what is making a request. - **Authorization (RBAC):** Determines which
actions are allowed. - **Admission control:** Validates or modifies API
requests before persistence. - **ServiceAccounts:** Provide identities
for workloads. - **Secrets:** Store sensitive values; configure
encryption at rest and least-privilege access. - **NetworkPolicies:**
Restrict network communication where supported. - **Pod Security
Standards / admission controls:** Help enforce Pod security
requirements. - **Image security:** Use trusted images, scanning, and
controlled registries. - **Audit logging:** Records API activity when
configured. - **Least privilege:** Grant only the permissions needed.

## 12. Where Can Kubernetes Be Installed or Used?

Kubernetes can run on physical servers, virtual machines, local
development environments, and managed cloud platforms.

### 12.1 On-Premises / Bare Metal

Kubernetes can be installed in an organization's own data center on
physical servers or virtual machines.

Common approaches: - kubeadm-based deployment - Vendor-supported
Kubernetes distributions - Enterprise platforms such as Red Hat
OpenShift

**Use cases:** Data-center workloads, regulatory or data-location
requirements, and environments requiring direct infrastructure control.

**Considerations:** The organization may be responsible for hardware,
networking, upgrades, availability, backups, and operations.

### 12.2 Local Development and Learning

-   **Minikube:** Runs a local Kubernetes cluster, commonly on a laptop
    or workstation.
-   **kind (Kubernetes IN Docker):** Runs Kubernetes clusters using
    containers as nodes; useful for testing and development.
-   **k3d:** Runs lightweight K3s clusters in Docker.
-   **Docker Desktop Kubernetes:** Provides a local Kubernetes option in
    supported Docker Desktop configurations.

These options are useful for learning and testing, but they do not
automatically reproduce production architecture or scale.

### 12.3 Managed Cloud Kubernetes

  -----------------------------------------------------------------------
  Platform                Provider                Description
  ----------------------- ----------------------- -----------------------
  **AKS (Azure Kubernetes Microsoft Azure         Managed Kubernetes
  Service)**                                      service integrated with
                                                  Azure

  **EKS (Amazon Elastic   AWS                     Managed Kubernetes
  Kubernetes Service)**                           service integrated with
                                                  AWS

  **GKE (Google           Google Cloud            Managed Kubernetes
  Kubernetes Engine)**                            service integrated with
                                                  Google Cloud

  **Oracle Kubernetes     Oracle Cloud            Managed Kubernetes
  Engine (OKE)**          Infrastructure          service on OCI

  **DigitalOcean          DigitalOcean            Managed Kubernetes
  Kubernetes (DOKS)**                             service

  **IBM Cloud Kubernetes  IBM Cloud               Managed Kubernetes
  Service**                                       offering
  -----------------------------------------------------------------------

In managed services, the provider operates some components---often
including the control plane---while customers remain responsible for
application configuration, workload security, and other responsibilities
defined by the service model.

### 12.4 Kubernetes Distributions and Platforms

-   **Red Hat OpenShift:** Enterprise application platform built around
    Kubernetes.
-   **Rancher / SUSE Rancher:** Tools and platform capabilities for
    managing Kubernetes environments.
-   **K3s:** Lightweight Kubernetes distribution designed for
    resource-constrained or edge environments.
-   **Kubeadm:** Tool for bootstrapping Kubernetes clusters; it is not a
    complete managed platform.

## 13. Typical Kubernetes Deployment Workflow

1.  Build an application container image using a tool such as Docker or
    Buildah.
2.  Push the image to a container registry.
3.  Define Kubernetes resources in YAML manifests or a packaging tool
    such as Helm.
4.  Submit the configuration using `kubectl` or a deployment system.
5.  The API server validates and stores the requested state.
6.  Controllers create or update workload objects.
7.  The scheduler assigns unscheduled Pods to suitable nodes.
8.  The kubelet on each selected node asks the runtime to pull images
    and start containers.
9.  The networking and storage systems configure connectivity and
    mounts.
10. Controllers and kubelets continually report and reconcile state.

## 14. Useful kubectl Commands

``` bash
# Check cluster connection and API endpoint
kubectl cluster-info

# List nodes
kubectl get nodes -o wide

# List Pods in the current namespace
kubectl get pods

# List Pods across all namespaces
kubectl get pods -A

# Inspect a resource
kubectl describe pod <pod-name>

# View logs
kubectl logs <pod-name>

# View Services
kubectl get services

# View Deployments
kubectl get deployments

# Apply a manifest
kubectl apply -f deployment.yaml

# Show current configuration context
kubectl config current-context
```

## 15. Key Differences: Control Plane vs. Worker Node

  -----------------------------------------------------------------------
  Area                    Control Plane           Worker Node
  ----------------------- ----------------------- -----------------------
  Main purpose            Manages and coordinates Runs application
                          the cluster             workloads

  Typical components      API server, etcd,       kubelet, container
                          scheduler, controller   runtime, commonly
                          manager, optional cloud kube-proxy, Pods
                          controller manager      

  Scheduling              Selects a node for a    Runs Pods assigned to
                          Pod                     it

  State                   Stores and reconciles   Reports node and
                          desired cluster state   workload status

  Application containers  Usually avoids running  Runs application
                          ordinary application    containers
                          workloads in production 
                          control-plane nodes     
  -----------------------------------------------------------------------

## 16. Common Interview Questions

1.  What is Kubernetes, and why is it used?
2.  What is the difference between a container and a Pod?
3.  Explain Kubernetes cluster architecture.
4.  What are the components of the control plane?
5.  What is the role of kube-apiserver?
6.  Why does Kubernetes use etcd?
7.  What does kube-scheduler do?
8.  What is the difference between kubelet and kube-proxy?
9.  What is a container runtime, and what is CRI?
10. What happens after you run `kubectl apply -f deployment.yaml`?
11. What is the difference between a Deployment and a StatefulSet?
12. What is the difference between a Service and an Ingress?
13. What is CNI, and why is it required?
14. How does Kubernetes provide self-healing?
15. What is the difference between Minikube and AKS/EKS/GKE?
16. Which Kubernetes components are managed by a cloud provider in a
    managed service?
17. How do PV, PVC, and StorageClass work together?
18. How does RBAC work in Kubernetes?
19. What happens when a worker node becomes unavailable?
20. How would you troubleshoot a Pod stuck in `Pending` or
    `CrashLoopBackOff`?

## 17. Recommended Learning Sequence

1.  Containers and container images
2.  Kubernetes purpose, history, and use cases
3.  Cluster architecture and control-plane components
4.  Worker-node components and Pod lifecycle
5.  Pods, Deployments, ReplicaSets, and StatefulSets
6.  Services, DNS, Ingress, and networking
7.  ConfigMaps, Secrets, and environment variables
8.  Storage: PV, PVC, and StorageClass
9.  Scheduling: requests, limits, affinity, taints, and tolerations
10. Health probes, scaling, rolling updates, and rollback
11. RBAC, security, and NetworkPolicies
12. Observability, troubleshooting, upgrades, and backup/restore
13. Hands-on practice with Minikube or kind
14. Cloud deployment with AKS, EKS, or GKE

## 18. Quick Recap

-   **Kubernetes** orchestrates containerized workloads.
-   A **cluster** consists of a control plane and worker nodes.
-   The **API server** is the primary interface to the cluster.
-   **etcd** stores cluster state.
-   The **scheduler** selects nodes for Pods.
-   **Controllers** reconcile actual state with desired state.
-   The **kubelet** manages Pods on a node.
-   The **container runtime** runs containers.
-   **Services and cluster networking** enable workload communication.
-   Kubernetes can run on-premises, locally, or through managed cloud
    services such as AKS, EKS, and GKE.
