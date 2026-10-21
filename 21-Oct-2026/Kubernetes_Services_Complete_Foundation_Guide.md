# Kubernetes Services --- Complete Foundation Guide

**Audience:** Beginner to intermediate Kubernetes learners\
**Goal:** Understand why Services exist, how they work, when to use each
type, limitations, best practices, and hands-on examples.

------------------------------------------------------------------------

## 1. Learning objectives

By the end of this session, learners should be able to:

-   Explain why a Kubernetes Service is needed.
-   Describe how Pods, labels, selectors, ports, and endpoints work
    together.
-   Create and test `ClusterIP`, `NodePort`, `LoadBalancer`, and
    headless Services.
-   Choose an appropriate Service type for a real scenario.
-   Troubleshoot common Service connectivity problems.
-   Apply practical security and operational best practices.

## 2. Foundation: What problem does a Service solve?

### 2.1 Pods are temporary

A Pod is the smallest deployable unit in Kubernetes. A Pod gets an IP
address, but Pods are replaceable:

-   A Pod can be deleted and recreated.
-   A Deployment rollout can replace Pods.
-   Scaling a Deployment changes the number of Pods.
-   A replacement Pod may receive a different IP address.

Therefore, applications should generally not depend on a specific Pod
IP.

### 2.2 Example without a Service

Imagine a frontend application needs to call a backend API.

Today, the backend Pod has IP `10.244.1.8`. After a restart or rollout,
the replacement Pod might have IP `10.244.2.11`. If the frontend is
configured with the old IP, the connection may fail.

Hard-coding Pod IPs is fragile because Pod IPs are not stable
application endpoints.

### 2.3 What is a Kubernetes Service?

A **Service** is a Kubernetes API object that provides a stable way to
reach a logical set of backend Pods. It normally discovers those Pods
using labels and a selector, and Kubernetes tracks the eligible backends
through EndpointSlices.

Think of a Service as a stable contact number for a changing group of
Pods.

A Service can provide:

-   A stable virtual IP and DNS name (for common Service types).
-   A consistent destination while Pods are replaced or scaled.
-   Distribution of connections across eligible backend endpoints.
-   Service discovery for communication between applications.
-   An internal or externally reachable access point, depending on its
    type and configuration.

**Important:** A Service does not create or manage application Pods. A
Deployment or StatefulSet normally manages the Pods; the Service
provides a network endpoint for reaching them.

## 3. Core concepts to understand first

### 3.1 Labels and selectors

Labels are key-value metadata attached to Kubernetes objects. A Service
selector matches Pod labels to decide which Pods are backends.

Example Pod labels:

``` yaml
labels:
  app: nginx
  tier: frontend
```

A selector such as `app: nginx` matches Pods with that label. It does
not require every other label to match.

The selector must match the labels on the **Pod template** created by
the Deployment, not just the Deployment's own metadata.

### 3.2 Ports: `port`, `targetPort`, and `nodePort`

  -----------------------------------------------------------------------
  Field                               Meaning
  ----------------------------------- -----------------------------------
  `port`                              Port exposed by the Service itself.
                                      Clients connect to this port.

  `targetPort`                        Port on the selected Pod/container
                                      where traffic is sent. It can be a
                                      number or a named container port.

  `nodePort`                          Port opened on cluster nodes for a
                                      `NodePort` Service and also
                                      normally used by a `LoadBalancer`
                                      Service. Kubernetes allocates one
                                      if omitted for a NodePort Service.
  -----------------------------------------------------------------------

Example:

``` yaml
ports:
  - port: 80
    targetPort: 8080
```

A client connects to Service port `80`; traffic is forwarded to port
`8080` on an eligible backend Pod.

The container does not have to listen on the same port number as the
Service. The `targetPort` must match the port on which the application
actually listens.

### 3.3 Service traffic flow

A simplified flow for an internal Service is:

``` text
Client Pod
   |
   | connects to Service DNS/IP and Service port
   v
Kubernetes Service virtual IP
   |
   | Service data plane selects an eligible endpoint
   v
Backend Pod IP : targetPort
```

The implementation may use `kube-proxy` with iptables/IPVS or another
compatible data plane such as an eBPF-based implementation. Do not
assume every cluster uses the same implementation.

### 3.4 EndpointSlices

Kubernetes maintains EndpointSlice objects to represent the backend
endpoints associated with a Service. They help Kubernetes and the
networking data plane track which Pod IPs are eligible to receive
traffic.

Useful commands:

``` bash
kubectl get endpointslices
kubectl get endpointslices -l kubernetes.io/service-name=nginx-service
kubectl describe service nginx-service
```

`kubectl get endpoints` is also useful in many clusters, but
EndpointSlices are the modern API used to represent Service endpoints.

### 3.5 DNS and service discovery

Within a typical cluster, a Service named `backend` in namespace
`default` can usually be resolved by Pods in that namespace as:

``` text
backend
```

A fully qualified name is typically:

``` text
backend.default.svc.cluster.local
```

Replace `default` with the actual namespace. The cluster domain is
commonly `cluster.local`, but administrators can configure a different
domain.

DNS provides name resolution; it does not itself guarantee that the
application is healthy or that network policy allows the connection.

------------------------------------------------------------------------

## 4. Prepare a foundation lab

This lab creates an NGINX Deployment with two replicas. We will then
expose it using different Service types.

### 4.1 Create a namespace (optional but recommended for a clean lab)

``` bash
kubectl create namespace service-lab
kubectl config set-context --current --namespace=service-lab
```

The second command changes the default namespace for the current kubectl
context. To return to the previous namespace later, set it explicitly or
use `-n`.

### 4.2 Create a Deployment

Save as `nginx-deployment.yaml`:

``` yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nginx-deployment
  labels:
    app: nginx
spec:
  replicas: 2
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
          image: nginx:1.28
          ports:
            - name: http
              containerPort: 80
```

Apply and verify:

``` bash
kubectl apply -f nginx-deployment.yaml
kubectl get deployments
kubectl get pods -o wide
kubectl get pods --show-labels
```

`containerPort: 80` documents the port expected in the container; it
does not, by itself, publish the application outside the Pod or enforce
that the process listens on that port.

### 4.3 Verify labels

``` bash
kubectl get pods -l app=nginx
```

The Service examples below use `selector: app: nginx` to find these
Pods.

------------------------------------------------------------------------

## 5. The four Service patterns in this session

  -----------------------------------------------------------------------
  Type                    Typical reachability    Common use
  ----------------------- ----------------------- -----------------------
  `ClusterIP`             Inside the cluster      Internal APIs, backend
                                                  services, databases

  `NodePort`              Through a node IP and   Labs, limited external
                          allocated node port,    access, environments
                          subject to              without a load-balancer
                          networking/firewall     integration
                          rules                   

  `LoadBalancer`          Through an external or  Applications that need
                          internal load balancer, a load-balancer
                          depending on the        frontend
                          platform and            
                          configuration           

  Headless                DNS returns endpoint    Stateful applications
  (`clusterIP: None`)     addresses rather than a and direct endpoint
                          normal Service virtual  discovery
                          IP                      
  -----------------------------------------------------------------------

A headless Service is a Service configuration, not a separate
`spec.type` value. It is commonly used with `type: ClusterIP` and
`clusterIP: None`.

------------------------------------------------------------------------

## 6. ClusterIP Service

### 6.1 What is ClusterIP?

`ClusterIP` is the default Service type. Kubernetes allocates a virtual
IP from the cluster's Service address range. It is normally reachable
only from within the cluster, subject to routing and network policy.

### 6.2 When should we use it?

Use `ClusterIP` when a service should be reached by other Pods or
internal clients, for example:

-   Frontend Pods calling backend API Pods.
-   An API calling an internal worker service.
-   Applications connecting to an internal database endpoint.
-   Internal microservice-to-microservice communication.

It is the usual starting point for internal application traffic.

### 6.3 YAML example

Save as `clusterip-service.yaml`:

``` yaml
apiVersion: v1
kind: Service
metadata:
  name: nginx-service
spec:
  type: ClusterIP
  selector:
    app: nginx
  ports:
    - name: http
      port: 80
      targetPort: http
      protocol: TCP
```

Here `targetPort: http` refers to the named container port `http` in the
Deployment. You can use `targetPort: 80` instead.

Apply and inspect:

``` bash
kubectl apply -f clusterip-service.yaml
kubectl get service nginx-service
kubectl describe service nginx-service
kubectl get endpointslices -l kubernetes.io/service-name=nginx-service
```

### 6.4 Test it

Run a temporary client Pod:

``` bash
kubectl run curl-client --image=curlimages/curl:8.10.1 --restart=Never -it --rm -- \
  curl -sS http://nginx-service
```

If the terminal does not attach as expected, create the Pod first and
use `kubectl logs` or `kubectl exec` to test it. A successful request
should return the NGINX welcome page HTML.

You can also test the Service DNS name:

``` bash
kubectl run dns-client --image=busybox:1.36 --restart=Never -it --rm -- \
  nslookup nginx-service
```

### 6.5 Advantages

-   Simple and commonly the right default.
-   Stable internal name and virtual IP.
-   Decouples clients from Pod IP changes.
-   Avoids exposing the application directly to external clients.

### 6.6 Limitations

-   Not normally reachable directly from outside the cluster.
-   Requires working cluster networking and DNS for name-based access.
-   Does not make an application healthy just because the Service
    exists.
-   Does not provide application-level authentication, authorization, or
    encryption by itself.

------------------------------------------------------------------------

## 7. NodePort Service

### 7.1 What is NodePort?

A `NodePort` Service exposes a port on cluster nodes. Clients can
attempt to connect using:

``` text
<NodeIP>:<NodePort>
```

Kubernetes normally allocates the node port from the configured NodePort
range (commonly `30000–32767`). A cluster administrator can configure a
different range.

NodePort Services also have a ClusterIP unless configured otherwise, so
they can normally be reached internally as well.

### 7.2 YAML example

Save as `nodeport-service.yaml`:

``` yaml
apiVersion: v1
kind: Service
metadata:
  name: nginx-nodeport
spec:
  type: NodePort
  selector:
    app: nginx
  ports:
    - name: http
      port: 80
      targetPort: http
      nodePort: 30080
      protocol: TCP
```

Apply and inspect:

``` bash
kubectl apply -f nodeport-service.yaml
kubectl get service nginx-nodeport
kubectl describe service nginx-nodeport
```

If port `30080` is already allocated or outside the configured range,
Kubernetes will reject the Service. You can omit `nodePort` and allow
Kubernetes to allocate a port.

### 7.3 How do you access it?

In a suitable lab or cluster, try:

``` text
http://<reachable-node-ip>:30080
```

The node IP must be reachable from the client. Firewall rules, cloud
security controls, routing, cluster configuration, and local firewall
rules may block the connection. On managed cloud clusters, do not assume
that every node has a public IP.

### 7.4 When should we use it?

-   Hands-on learning and demonstrations.
-   Small controlled environments where direct node access is
    acceptable.
-   As a building block behind a load balancer in some cluster/platform
    configurations.

### 7.5 Advantages

-   Provides a straightforward node-IP-and-port access method.
-   Does not inherently require a cloud load-balancer integration.
-   Useful for understanding how Services expose applications.

### 7.6 Limitations

-   Clients must know a reachable node address and the allocated port.
-   NodePort exposes a high port on cluster nodes and needs deliberate
    firewall controls.
-   Node IPs can change and individual nodes may become unavailable.
-   It is usually less convenient than a managed load balancer for
    production internet-facing applications.
-   It does not automatically provide a DNS name, TLS certificate, or
    web application firewall.

**Best practice:** Do not expose NodePorts broadly to the internet
unless there is a specific, reviewed need and suitable network
restrictions.

------------------------------------------------------------------------

## 8. LoadBalancer Service

### 8.1 What is LoadBalancer?

A Service with `type: LoadBalancer` asks the Kubernetes environment or
its load-balancer integration to provision or configure a load-balancer
frontend. On cloud platforms, this commonly integrates with the
provider's load-balancing service.

The exact result depends on the platform, cloud controller, installed
controllers, annotations, and configuration. It may create an
external/public or internal/private load balancer.

### 8.2 YAML example

Save as `loadbalancer-service.yaml`:

``` yaml
apiVersion: v1
kind: Service
metadata:
  name: nginx-loadbalancer
spec:
  type: LoadBalancer
  selector:
    app: nginx
  ports:
    - name: http
      port: 80
      targetPort: http
      protocol: TCP
```

Apply and watch the status:

``` bash
kubectl apply -f loadbalancer-service.yaml
kubectl get service nginx-loadbalancer --watch
```

Inspect it in another terminal:

``` bash
kubectl describe service nginx-loadbalancer
```

Look at `EXTERNAL-IP` or the platform-specific address field.
Provisioning may take time. In some environments the address may remain
pending because there is no compatible load-balancer integration.

### 8.3 When should we use it?

-   Exposing a service through a cloud provider's network load balancer.
-   Providing a stable frontend address for an application or TCP/UDP
    service.
-   Private/internal load-balancing use cases when supported and
    configured by the platform.

### 8.4 Advantages

-   Can provide a stable load-balancer frontend.
-   Hides the need for clients to choose individual worker nodes.
-   Integrates with provider networking and health-check mechanisms,
    depending on the implementation.
-   Often a good fit for non-HTTP services or straightforward external
    exposure.

### 8.5 Limitations and costs

-   A cloud provider may charge for the load balancer and related data
    transfer.
-   Behavior and annotations vary between providers and controllers.
-   It does not automatically mean the application has HTTPS, a WAF, or
    authentication.
-   It may expose a public endpoint unless an internal/private
    configuration is explicitly used.
-   A separate LoadBalancer Service for each application can create
    extra load balancers and costs, depending on the platform.

### 8.6 LoadBalancer vs Ingress/Gateway

For HTTP/HTTPS applications, an Ingress controller or Gateway API
implementation can often route many hostnames and paths through shared
entry infrastructure. The Ingress or Gateway resource alone does not
implement traffic handling; a controller or gateway implementation is
required.

A `LoadBalancer` Service exposes a network frontend for that Service. An
Ingress/Gateway can provide HTTP-aware routing such as host-based and
path-based rules, depending on the implementation.

Example:

-   `shop.example.com` → frontend application
-   `api.example.com` → backend API
-   `example.com/images` → image service

A common architecture is one external load balancer in front of an
Ingress/Gateway controller, with internal `ClusterIP` Services behind
it. The exact architecture depends on the controller and platform.

------------------------------------------------------------------------

## 9. Headless Service

### 9.1 What is a headless Service?

A headless Service is created by setting:

``` yaml
clusterIP: None
```

Instead of providing a normal virtual ClusterIP for the Service, DNS can
return the IP addresses of the backing endpoints. Clients can then
discover individual endpoints and connect directly to them.

A headless Service is useful when the client needs endpoint-level
discovery rather than a single virtual IP.

### 9.2 YAML example

Save as `headless-service.yaml`:

``` yaml
apiVersion: v1
kind: Service
metadata:
  name: nginx-headless
spec:
  clusterIP: None
  selector:
    app: nginx
  ports:
    - name: http
      port: 80
      targetPort: http
      protocol: TCP
```

Apply and inspect:

``` bash
kubectl apply -f headless-service.yaml
kubectl get service nginx-headless
kubectl get endpointslices -l kubernetes.io/service-name=nginx-headless
```

The Service should show `CLUSTER-IP` as `None`.

Test DNS from inside the cluster:

``` bash
kubectl run dns-client --image=busybox:1.36 --restart=Never -it --rm -- \
  nslookup nginx-headless
```

DNS behavior depends on the resolver and endpoint readiness settings. A
headless Service normally returns records for eligible endpoint
addresses rather than a single ClusterIP.

### 9.3 When should we use it?

-   Stateful applications where clients need to discover individual
    Pods.
-   StatefulSets that need stable per-Pod DNS identities.
-   Distributed systems where the application itself performs peer
    discovery or connection selection.

### 9.4 Headless Service with StatefulSet

A common StatefulSet pattern is to use a headless Service as the
governing Service. StatefulSet Pods can then receive stable DNS
identities, typically in a form like:

``` text
< pod-name >.< headless-service-name >.< namespace >.svc.< cluster-domain >
```

For example, a Pod named `postgres-0` governed by a headless Service
named `postgres` in namespace `database` could have a DNS name like:

``` text
postgres-0.postgres.database.svc.cluster.local
```

The exact DNS name depends on the Pod name, Service name, namespace, and
cluster domain. The governing Service must be configured correctly in
the StatefulSet.

### 9.5 Advantages

-   Supports endpoint-level discovery.
-   Useful for StatefulSets and distributed applications.
-   Avoids the normal Service virtual IP and its virtual-IP
    load-balancing behavior.

### 9.6 Limitations

-   Clients may need to handle multiple endpoint addresses and choose
    connections themselves.
-   It does not provide the usual single virtual-IP abstraction.
-   DNS caching and endpoint changes can affect client behavior.
-   Application-level failover and load balancing may be the
    application's responsibility.

**Important:** A headless Service does not automatically make an
application stateful, and it does not create persistent storage.
StatefulSets and persistent volumes address different concerns.

------------------------------------------------------------------------

## 10. Quick decision guide: which type should I choose?

  -----------------------------------------------------------------------
  Requirement             Usual starting point    Why
  ----------------------- ----------------------- -----------------------
  One Pod needs to call   `ClusterIP`             Stable internal
  another application                             endpoint
  inside the cluster                              

  A backend API should    `ClusterIP`             Internal-only by
  not be directly exposed                         default
  to the internet                                 

  A quick lab needs       `NodePort`              Direct node port access
  access through a node                           
  IP and port                                     

  A TCP/UDP application   `LoadBalancer`          Provider-integrated
  needs a cloud                                   frontend
  load-balancer frontend                          

  An application needs a  Ingress or Gateway,     HTTP-aware routing
  public HTTP/HTTPS       usually with a suitable 
  endpoint with host/path frontend Service        
  routing                                         

  A StatefulSet's peers   Headless Service        DNS can return endpoint
  need individual Pod                             addresses
  discovery                                       

  A service needs a       `LoadBalancer` with     Depends on
  private cloud load      provider-specific       provider/controller
  balancer                internal configuration  

  A service must be       No universal answer     Evaluate routing,
  reachable from outside                          security, and platform
  the cluster without any                         support first
  load-balancer or                                
  ingress solution                                
  -----------------------------------------------------------------------

------------------------------------------------------------------------

## 11. Service session: complete hands-on sequence

Run these steps in order. Use the same Deployment and create one Service
at a time if you want to avoid maintaining multiple test entry points
simultaneously.

### Step 1 --- Deploy the application

``` bash
kubectl apply -f nginx-deployment.yaml
kubectl rollout status deployment/nginx-deployment
kubectl get pods -l app=nginx -o wide
```

### Step 2 --- Create a ClusterIP Service

``` bash
kubectl apply -f clusterip-service.yaml
kubectl get svc nginx-service
kubectl get endpointslices -l kubernetes.io/service-name=nginx-service
```

Test from a temporary client Pod:

``` bash
kubectl run curl-client --image=curlimages/curl:8.10.1 --restart=Never -it --rm -- \
  curl -sS http://nginx-service
```

### Step 3 --- Observe endpoint changes during scaling

``` bash
kubectl scale deployment nginx-deployment --replicas=4
kubectl get pods -l app=nginx
kubectl get endpointslices -l kubernetes.io/service-name=nginx-service
```

The Service selector can discover the newly created Pods once they
become eligible endpoints. Scale back afterward if desired:

``` bash
kubectl scale deployment nginx-deployment --replicas=2
```

### Step 4 --- Try NodePort

``` bash
kubectl apply -f nodeport-service.yaml
kubectl get svc nginx-nodeport
```

Inspect the assigned node port and test only from a client that can
reach a node IP. If access fails, check routing and firewall rules as
well as Kubernetes configuration.

### Step 5 --- Try LoadBalancer where supported

``` bash
kubectl apply -f loadbalancer-service.yaml
kubectl get svc nginx-loadbalancer --watch
```

Use this in a supported cloud or lab environment. A local cluster may
not provision a load balancer automatically.

### Step 6 --- Try a headless Service

``` bash
kubectl apply -f headless-service.yaml
kubectl get svc nginx-headless
kubectl get endpointslices -l kubernetes.io/service-name=nginx-headless
```

Compare the Service's `CLUSTER-IP` value with the ClusterIP Service and
test DNS inside the cluster.

### Step 7 --- Clean up

If you created the namespace and changed your current context to it:

``` bash
kubectl delete namespace service-lab
kubectl config set-context --current --namespace=default
```

Deleting the namespace removes the lab resources in that namespace. If
you did not use a separate namespace, delete only the resources you
created.

------------------------------------------------------------------------

## 12. Best practices

1.  **Use a Service name, not a Pod IP.** Pod IPs are ephemeral.
2.  **Prefer `ClusterIP` for internal application-to-application
    communication.** Expose only what needs to be exposed.
3.  **Use precise selectors.** A selector that is too broad can send
    traffic to the wrong Pods; one that matches nothing produces no
    endpoints.
4.  **Make ports explicit.** Use meaningful port names when appropriate,
    and ensure `targetPort` matches the application's listening port.
5.  **Add readiness probes to applications.** Readiness helps Kubernetes
    decide when a Pod should receive Service traffic. A Service does not
    replace readiness checks.
6.  **Check endpoints during troubleshooting.** A Service with no
    eligible endpoints cannot forward traffic to a backend Pod.
7.  **Restrict external access.** Use cloud firewall/security controls
    and Kubernetes NetworkPolicies where supported. A Service type alone
    is not a security policy.
8.  **Use TLS and application security.** `LoadBalancer` and `NodePort`
    do not automatically provide HTTPS, authentication, or
    authorization.
9.  **Consider Ingress/Gateway for HTTP/HTTPS.** Host/path routing can
    avoid creating a separate external load balancer for every web
    application, depending on the implementation.
10. **Control costs.** Review how many external load balancers are
    created and whether they are necessary.
11. **Use headless Services intentionally.** Choose them when endpoint
    discovery is needed; do not select them just because they sound
    faster.
12. **Use namespaces and clear names.** For example, `orders-api`,
    `payments-db`, and `frontend`.
13. **Use NetworkPolicy for segmentation.** Where a NetworkPolicy
    implementation is installed, allow only the traffic that is
    required. Policies are not enforced by every network plugin in the
    same way.
14. **Do not assume `externalTrafficPolicy`, session affinity, or
    source-IP behavior is identical everywhere.** Validate provider and
    cluster behavior before relying on it.
15. **Test failover and rollout behavior.** Verify the application
    continues to work as Pods are replaced or scaled.

------------------------------------------------------------------------

## 13. Important limitations and misconceptions

-   **A Service is not a Deployment.** The Deployment manages replicas;
    the Service provides a stable network endpoint.
-   **A Service does not create Pods.** A selector finds existing
    matching Pods.
-   **A Service does not guarantee application health.** Use
    readiness/liveness probes and application monitoring appropriately.
-   **A Service is not a DNS server.** Cluster DNS resolves Service
    names; a Service object and cluster DNS work together.
-   **A Service does not automatically encrypt traffic.** Use TLS or a
    suitable service-mesh/network security design when required.
-   **A ClusterIP is not normally a public IP.** It is a virtual address
    from the cluster's Service range.
-   **NodePort does not mean every node is publicly reachable.** The
    node IP must be reachable and firewall rules must allow the traffic.
-   **LoadBalancer does not always mean public.** Many platforms support
    internal/private load balancers when configured correctly.
-   **Headless is not a fourth `spec.type`.** It is commonly a
    `ClusterIP` Service with `clusterIP: None`.
-   **The Service selector must match Pod labels.** A valid YAML file
    can still create a Service with no backends if the labels do not
    match.
-   **NetworkPolicy and Service are different resources.** A Service
    provides a destination; NetworkPolicy controls allowed network
    communication when enforced by the cluster's networking
    implementation.
-   **ExternalName is another Service type.** It maps a Service name to
    a DNS name using a CNAME and does not proxy traffic to Pods. It is
    outside the four main patterns in this lab but is worth knowing.

------------------------------------------------------------------------

## 14. Troubleshooting checklist

If the Service does not work, investigate in this order.

### 14.1 Does the Service exist?

``` bash
kubectl get svc
kubectl describe svc nginx-service
```

Check the type, ClusterIP, port, targetPort, selector, and events.

### 14.2 Does the selector match the Pods?

``` bash
kubectl get pods --show-labels
kubectl get pods -l app=nginx
```

If no Pods match, correct the Service selector or Pod labels.

### 14.3 Are there endpoints?

``` bash
kubectl get endpointslices -l kubernetes.io/service-name=nginx-service
```

If there are no usable endpoints, check selector matching, Pod
readiness, and endpoint conditions.

### 14.4 Is the application listening on the expected port?

``` bash
kubectl logs deployment/nginx-deployment
kubectl describe pod <pod-name>
```

Verify the actual application listening port and the Service's
`targetPort`. `containerPort` alone does not start a listener.

### 14.5 Does DNS resolve?

From a client Pod:

``` bash
nslookup nginx-service
```

If name resolution fails, check the name, namespace, Pod DNS
configuration, and cluster DNS health.

### 14.6 Can the client reach the Service IP?

Test by Service DNS name first, then inspect the Service IP and
endpoints. Check NetworkPolicies, CNI/data-plane health, routing, and
application logs.

### 14.7 NodePort or LoadBalancer access fails

Check:

-   Is the chosen node IP reachable from the client?
-   Are cloud security groups, firewall rules, routing tables, and local
    firewalls permitting the traffic?
-   For LoadBalancer, is the external/internal address provisioned?
-   Does the provider or controller support the requested configuration?
-   Are the backend endpoints ready and listening?

Avoid opening broad firewall access as a first troubleshooting step.

------------------------------------------------------------------------

## 15. Interview questions and answers

### Q1. What is a Kubernetes Service?

A Kubernetes Service provides a stable network endpoint for a logical
group of Pods. It commonly uses labels and selectors to discover
eligible backend Pods and enables clients to reach them without
depending on changing Pod IPs.

### Q2. Why do we need a Service if every Pod already has an IP?

Pod IPs can change when Pods are recreated or scaled. A Service provides
a stable name and, for common Service types, a stable virtual IP that
clients can use while backend Pods change.

### Q3. What is the default Service type?

`ClusterIP`.

### Q4. What is the difference between `port` and `targetPort`?

`port` is the port clients use on the Service. `targetPort` is the port
on the backend Pod to which traffic is sent.

### Q5. What is the difference between ClusterIP and NodePort?

ClusterIP is normally used for internal cluster access. NodePort exposes
a port on cluster nodes, enabling access through a reachable node IP and
the allocated node port, subject to network controls.

### Q6. Does a LoadBalancer Service always create a public IP?

No. Behavior depends on the platform and configuration. Some platforms
support internal/private load balancers; public exposure should not be
assumed or left unreviewed.

### Q7. What is a headless Service?

A Service configured with `clusterIP: None`. DNS can return endpoint
addresses instead of a single virtual ClusterIP, which is useful for
endpoint discovery and StatefulSets.

### Q8. What happens if a Service selector does not match any Pods?

The Service object may still exist, but it has no usable backend
endpoints and requests cannot be forwarded to matching application Pods.

### Q9. Does a Service load-balance every individual HTTP request?

Do not assume that it balances every HTTP request independently. Common
Service data planes select a backend for connections or flows; behavior
depends on the implementation and protocol. HTTP-aware per-request
routing is typically provided by an ingress controller, gateway, proxy,
or application layer.

### Q10. How would you troubleshoot a Service that is not working?

Check the Service and its ports, selector labels, EndpointSlices, Pod
readiness, application listening port, DNS resolution, NetworkPolicies,
and cluster networking. For NodePort or LoadBalancer, also verify
routing and firewall/provider configuration.

### Q11. Can one Service select Pods from multiple Deployments?

Yes, if the Pods from those Deployments share labels matched by the
Service selector. This should be intentional because all matching
eligible Pods can receive traffic.

### Q12. What is ExternalName?

It is a Service type that maps a Service DNS name to an external DNS
name using a CNAME. It does not provide a normal ClusterIP or proxy
traffic to selected Pods.

------------------------------------------------------------------------

## 16. Knowledge check for learners

1.  Why is hard-coding a Pod IP a bad idea?
2.  Which Service type is the default?
3.  In `port: 8080` and `targetPort: 80`, which port does the client
    use?
4.  Why might a Service exist but have no working backend?
5.  Which Service type exposes a node port?
6.  Does `type: LoadBalancer` guarantee a public IP on every Kubernetes
    cluster?
7.  What does `clusterIP: None` mean?
8.  Which resource should you inspect to understand a Service's current
    backend endpoints?
9.  Which Kubernetes resource usually manages the desired number of
    application replicas?
10. For a production web app requiring host/path routing, what might you
    use instead of creating a separate external load balancer for every
    app?

### Suggested answers

1.  Pod IPs can change when Pods are replaced or scaled.
2.  `ClusterIP`.
3.  `8080`.
4.  The selector may not match Pods, Pods may not be ready, or the
    application may not be listening on the target port.
5.  `NodePort`.
6.  No; provider/controller support and configuration determine the
    outcome.
7.  It creates a headless Service without the normal ClusterIP virtual
    address.
8.  EndpointSlices (and `kubectl describe service` is also useful).
9.  Usually a Deployment for stateless workloads, or a StatefulSet for
    workloads needing stable identities.
10. An Ingress controller or Gateway API implementation, commonly backed
    by a suitable Service.

------------------------------------------------------------------------

## 17. Closing summary

-   **ClusterIP:** Start here for internal communication.
-   **NodePort:** Access through a reachable node IP and a node port;
    use carefully.
-   **LoadBalancer:** Use a supported load-balancer integration when a
    network frontend is needed.
-   **Headless Service:** Use `clusterIP: None` when clients need direct
    endpoint discovery, especially with StatefulSets.
-   **Remember:** The Service provides a stable way to find and reach
    eligible Pods; labels, selectors, ports, DNS, readiness, and
    networking must all line up for traffic to work.
