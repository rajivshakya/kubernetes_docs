# Kubernetes Network Policies -- Complete Hands-on Session

## 1. Session objective

In this session, we will understand Kubernetes Network Policies and
implement traffic restrictions for a simple three-tier application.

We will create three namespaces:

-   `frontend` -- frontend application
-   `backend` -- backend API
-   `db` -- database service

### Expected communication matrix

  Source     Destination   Expected result
  ---------- ------------- -----------------
  Frontend   Backend       ALLOWED
  Frontend   Database      DENIED
  Backend    Database      ALLOWED
  Backend    Frontend      DENIED
  Database   Frontend      DENIED
  Database   Backend       DENIED

The objective is to enforce least-privilege network access: each
application tier should communicate only with the tier it needs.

## 2. What is a Kubernetes Network Policy?

A NetworkPolicy is a Kubernetes resource that controls network traffic
to and from a group of Pods.

It can control:

-   **Ingress:** incoming traffic to selected Pods.
-   **Egress:** outgoing traffic from selected Pods.
-   **Pod selection:** which Pods the policy applies to, using labels.
-   **Namespace selection:** which namespaces are allowed as traffic
    sources or destinations.
-   **Ports and protocols:** which destination ports and protocols are
    permitted.

A NetworkPolicy works at the Pod network level. It is not a replacement
for authentication, authorization, TLS, or application-level security.

## 3. Why do we need Network Policies?

By default, in a Kubernetes cluster where no NetworkPolicy selects a
Pod, Pods are generally allowed to communicate with other Pods, subject
to the cluster networking implementation.

This can create unnecessary east-west access. For example, a frontend
Pod may be able to connect directly to a database Pod even though the
application architecture requires all database access to pass through
the backend.

Network Policies help us:

1.  Apply least-privilege network access.
2.  Isolate application tiers and namespaces.
3.  Reduce the impact of a compromised Pod.
4.  Restrict unnecessary east-west traffic.
5.  Meet security and compliance requirements.

**Important:** NetworkPolicy rules are additive. If multiple policies
select a Pod, the allowed traffic is the union of the rules from those
policies. A later policy does not override or cancel an earlier allow
rule.

## 4. How Network Policies work

A NetworkPolicy has four important parts:

-   `podSelector`: selects the Pods protected by the policy.
-   `policyTypes`: specifies `Ingress`, `Egress`, or both.
-   `ingress`: defines permitted incoming connections.
-   `egress`: defines permitted outgoing connections.

### Important behavior

-   A policy with `policyTypes: [Ingress]` isolates selected Pods for
    ingress. Only matching ingress traffic is allowed.
-   A policy with `policyTypes: [Egress]` isolates selected Pods for
    egress. Only matching egress traffic is allowed.
-   If a Pod is isolated for ingress but no ingress rule allows a
    connection, that connection is denied.
-   If a Pod is isolated for egress but no egress rule allows a
    connection, that connection is denied.
-   Policies are namespace-scoped. A policy created in one namespace
    selects Pods in that namespace only.
-   Namespace selectors use labels on Namespace objects, while pod
    selectors use labels on Pods.

## 5. Prerequisites and CNI support

NetworkPolicy enforcement depends on the cluster networking plugin
(CNI). The Kubernetes API may accept a NetworkPolicy even when the
installed network plugin does not enforce it.

Before the demo, confirm that your cluster CNI supports NetworkPolicy
enforcement.

Examples: - Calico supports Kubernetes NetworkPolicy. - Cilium supports
Kubernetes NetworkPolicy. - Some managed Kubernetes networking
configurations provide policy enforcement through their selected network
policy implementation.

For AKS, verify the cluster's configured network policy implementation
and its support for NetworkPolicy before the session. Do not assume that
every AKS networking mode enforces policies in the same way.

Check the cluster:

``` bash
kubectl get nodes -o wide
kubectl get pods -n kube-system
kubectl api-resources | grep -i networkpolicy
```

The last command confirms API resource availability, **not** enforcement
by the CNI.

## 6. Demo architecture

We will use BusyBox containers for a lightweight HTTP server and for
connectivity tests.

Each namespace will contain: - One Pod running BusyBox `httpd` on TCP
port `8080`. - One ClusterIP Service exposing that Pod on port `8080`.

We will use these service DNS names:

``` text
frontend.frontend.svc.cluster.local
backend.backend.svc.cluster.local
db.db.svc.cluster.local
```

The demo uses HTTP only to make connectivity visible. Do not use this
plain HTTP setup for production credentials or sensitive data.

## 7. Step 1 -- Create namespaces

Create a file named `01-namespaces.yaml`:

``` yaml
apiVersion: v1
kind: Namespace
metadata:
  name: frontend
  labels:
    name: frontend
---
apiVersion: v1
kind: Namespace
metadata:
  name: backend
  labels:
    name: backend
---
apiVersion: v1
kind: Namespace
metadata:
  name: db
  labels:
    name: db
```

Apply it:

``` bash
kubectl apply -f 01-namespaces.yaml
kubectl get namespaces --show-labels
```

Expected namespaces: `frontend`, `backend`, and `db`.

## 8. Step 2 -- Deploy demo applications and Services

Create a file named `02-applications.yaml`:

``` yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: frontend
  namespace: frontend
spec:
  replicas: 1
  selector:
    matchLabels:
      app: frontend
  template:
    metadata:
      labels:
        app: frontend
    spec:
      containers:
        - name: web
          image: busybox:1.36
          command: ["sh", "-c", "httpd -f -p 8080"]
          ports:
            - containerPort: 8080
---
apiVersion: v1
kind: Service
metadata:
  name: frontend
  namespace: frontend
spec:
  selector:
    app: frontend
  ports:
    - name: http
      port: 8080
      targetPort: 8080
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: backend
  namespace: backend
spec:
  replicas: 1
  selector:
    matchLabels:
      app: backend
  template:
    metadata:
      labels:
        app: backend
    spec:
      containers:
        - name: web
          image: busybox:1.36
          command: ["sh", "-c", "httpd -f -p 8080"]
          ports:
            - containerPort: 8080
---
apiVersion: v1
kind: Service
metadata:
  name: backend
  namespace: backend
spec:
  selector:
    app: backend
  ports:
    - name: http
      port: 8080
      targetPort: 8080
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: db
  namespace: db
spec:
  replicas: 1
  selector:
    matchLabels:
      app: db
  template:
    metadata:
      labels:
        app: db
    spec:
      containers:
        - name: web
          image: busybox:1.36
          command: ["sh", "-c", "httpd -f -p 8080"]
          ports:
            - containerPort: 8080
---
apiVersion: v1
kind: Service
metadata:
  name: db
  namespace: db
spec:
  selector:
    app: db
  ports:
    - name: http
      port: 8080
      targetPort: 8080
```

Apply the manifest:

``` bash
kubectl apply -f 02-applications.yaml
```

Verify:

``` bash
kubectl get pods -n frontend -o wide
kubectl get pods -n backend -o wide
kubectl get pods -n db -o wide

kubectl get svc -n frontend
kubectl get svc -n backend
kubectl get svc -n db
```

Wait until all three Pods are `Running` and Ready.

## 9. Step 3 -- Scenario 1: Test connectivity before Network Policies

At this stage, we have not applied any NetworkPolicy.

Open a shell in the frontend Pod:

``` bash
kubectl exec -it deploy/frontend -n frontend -- sh
```

From inside the Pod, test the backend:

``` sh
wget -T 3 -qO- http://backend.backend.svc.cluster.local:8080
```

Test the database:

``` sh
wget -T 3 -qO- http://db.db.svc.cluster.local:8080
```

Both requests should return an HTTP response if the cluster CNI allows
unrestricted Pod communication and DNS is working.

Exit:

``` sh
exit
```

Now test from the backend Pod:

``` bash
kubectl exec -it deploy/backend -n backend -- sh
```

Test database:

``` sh
wget -T 3 -qO- http://db.db.svc.cluster.local:8080
```

Test frontend:

``` sh
wget -T 3 -qO- http://frontend.frontend.svc.cluster.local:8080
```

Again, both should normally work before policies are applied.

**Teaching point:** Kubernetes namespaces provide logical separation,
but namespaces alone do not automatically block Pod-to-Pod network
traffic.

## 10. Step 4 -- Scenario 2: Implement the required Network Policies

We will now implement the required communication matrix.

### Policy design

1.  Frontend egress: allow only Backend Pods on TCP 8080 and DNS.
2.  Backend ingress: allow only Frontend Pods on TCP 8080.
3.  Backend egress: allow only DB Pods on TCP 8080 and DNS.
4.  DB ingress: allow only Backend Pods on TCP 8080.

This results in: - Frontend can call Backend. - Frontend cannot call
DB. - Backend can call DB. - Backend cannot call Frontend. - DB accepts
connections only from Backend.

### 10.1 Frontend NetworkPolicy

Create `03-frontend-policy.yaml`:

``` yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: frontend-egress-policy
  namespace: frontend
spec:
  podSelector:
    matchLabels:
      app: frontend
  policyTypes:
    - Egress
  egress:
    # Allow frontend Pods to call backend Pods on TCP 8080
    - to:
        - namespaceSelector:
            matchLabels:
              name: backend
          podSelector:
            matchLabels:
              app: backend
      ports:
        - protocol: TCP
          port: 8080

    # Allow DNS lookups through CoreDNS
    - to:
        - namespaceSelector:
            matchLabels:
              kubernetes.io/metadata.name: kube-system
          podSelector:
            matchLabels:
              k8s-app: kube-dns
      ports:
        - protocol: UDP
          port: 53
        - protocol: TCP
          port: 53
```

Apply:

``` bash
kubectl apply -f 03-frontend-policy.yaml
```

**Note:** The standard Kubernetes namespace label
`kubernetes.io/metadata.name` is normally present. CoreDNS commonly uses
the Pod label `k8s-app: kube-dns`, but verify the actual labels in your
cluster:

``` bash
kubectl get pods -n kube-system --show-labels
```

If your DNS Pods use different labels or run outside `kube-system`,
adjust the DNS selector accordingly. If the selector does not match the
DNS Pods, service-name lookups may fail even though the application
traffic rule is correct.

### 10.2 Backend NetworkPolicy

Create `04-backend-policy.yaml`:

``` yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: backend-network-policy
  namespace: backend
spec:
  podSelector:
    matchLabels:
      app: backend
  policyTypes:
    - Ingress
    - Egress

  ingress:
    # Allow incoming requests only from frontend Pods
    - from:
        - namespaceSelector:
            matchLabels:
              name: frontend
          podSelector:
            matchLabels:
              app: frontend
      ports:
        - protocol: TCP
          port: 8080

  egress:
    # Allow outgoing requests only to DB Pods
    - to:
        - namespaceSelector:
            matchLabels:
              name: db
          podSelector:
            matchLabels:
              app: db
      ports:
        - protocol: TCP
          port: 8080

    # Allow DNS lookups through CoreDNS
    - to:
        - namespaceSelector:
            matchLabels:
              kubernetes.io/metadata.name: kube-system
          podSelector:
            matchLabels:
              k8s-app: kube-dns
      ports:
        - protocol: UDP
          port: 53
        - protocol: TCP
          port: 53
```

Apply:

``` bash
kubectl apply -f 04-backend-policy.yaml
```

**Important selector detail:** In a NetworkPolicy peer, when
`namespaceSelector` and `podSelector` appear together in the same list
item, they are combined with AND logic. This selects the matching Pods
inside the matching namespace. If they are separate list items, they are
alternatives (OR logic).

### 10.3 Database NetworkPolicy

Create `05-db-policy.yaml`:

``` yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: db-ingress-policy
  namespace: db
spec:
  podSelector:
    matchLabels:
      app: db
  policyTypes:
    - Ingress
  ingress:
    # Accept connections only from backend Pods
    - from:
        - namespaceSelector:
            matchLabels:
              name: backend
          podSelector:
            matchLabels:
              app: backend
      ports:
        - protocol: TCP
          port: 8080
```

Apply:

``` bash
kubectl apply -f 05-db-policy.yaml
```

Verify all policies:

``` bash
kubectl get networkpolicy -A
kubectl describe networkpolicy frontend-egress-policy -n frontend
kubectl describe networkpolicy backend-network-policy -n backend
kubectl describe networkpolicy db-ingress-policy -n db
```

## 11. Step 5 -- Scenario 2 verification

### Test 1: Frontend → Backend (should ALLOW)

``` bash
kubectl exec deploy/frontend -n frontend -- \
  wget -T 3 -qO- http://backend.backend.svc.cluster.local:8080
```

Expected: HTTP response from the backend BusyBox server.

### Test 2: Frontend → Database (should DENY)

``` bash
kubectl exec deploy/frontend -n frontend -- \
  wget -T 3 -qO- http://db.db.svc.cluster.local:8080
```

Expected: timeout or connection failure.

Reason: frontend egress policy permits Backend Pods and DNS, but not DB
Pods.

### Test 3: Backend → Database (should ALLOW)

``` bash
kubectl exec deploy/backend -n backend -- \
  wget -T 3 -qO- http://db.db.svc.cluster.local:8080
```

Expected: HTTP response from the DB namespace's demo server.

### Test 4: Backend → Frontend (should DENY)

``` bash
kubectl exec deploy/backend -n backend -- \
  wget -T 3 -qO- http://frontend.frontend.svc.cluster.local:8080
```

Expected: timeout or connection failure.

Reason: backend egress policy does not permit frontend Pods.

### Test 5: Database → Backend (should DENY)

``` bash
kubectl exec deploy/db -n db -- \
  wget -T 3 -qO- http://backend.backend.svc.cluster.local:8080
```

Expected: timeout or connection failure.

Reason: backend ingress policy accepts traffic only from frontend Pods.
The database also has no egress allowance to backend.

## 12. Step 6 -- Scenario 3: Demonstrate default-deny behavior

A common security pattern is to begin by denying all ingress and egress
for selected Pods, then explicitly allow only required traffic.

For this isolated demo, create `06-default-deny-db.yaml`:

``` yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: db-default-deny
  namespace: db
spec:
  podSelector: {}
  policyTypes:
    - Ingress
    - Egress
```

Apply:

``` bash
kubectl apply -f 06-default-deny-db.yaml
```

This policy selects all Pods in the `db` namespace and isolates them for
both ingress and egress. Because it contains no allow rules, it allows
no ingress or egress traffic for those Pods.

**Important:** NetworkPolicy rules are additive. The existing
`db-ingress-policy` still allows Backend → DB on TCP 8080. Therefore,
the effective result is:

-   Backend → DB TCP 8080: ALLOWED by `db-ingress-policy`.
-   Other ingress to DB: DENIED.
-   DB egress: DENIED, because no policy allows DB egress.

Verify Backend → DB again:

``` bash
kubectl exec deploy/backend -n backend -- \
  wget -T 3 -qO- http://db.db.svc.cluster.local:8080
```

Expected: still allowed.

Now try Frontend → DB:

``` bash
kubectl exec deploy/frontend -n frontend -- \
  wget -T 3 -qO- http://db.db.svc.cluster.local:8080
```

Expected: denied.

This demonstrates how a default-deny policy can be combined with a
specific allow policy.

## 13. Understanding the final traffic flow

  -----------------------------------------------------------------------
  Source            Destination       Policy reason     Result
  ----------------- ----------------- ----------------- -----------------
  Frontend          Backend:8080      Frontend egress + ALLOWED
                                      Backend ingress   
                                      allow             

  Frontend          DB:8080           Frontend egress   DENIED
                                      does not allow DB 

  Backend           DB:8080           Backend egress +  ALLOWED
                                      DB ingress allow  

  Backend           Frontend:8080     Backend egress    DENIED
                                      does not allow    
                                      Frontend          

  DB                Backend:8080      Backend ingress   DENIED
                                      does not allow DB 

  DB                Frontend:8080     Frontend ingress  DENIED
                                      is not allowed;   
                                      DB egress is      
                                      isolated in       
                                      Scenario 3        
  -----------------------------------------------------------------------

## 14. Important interview and session concepts

### Q1. Does NetworkPolicy work at namespace level or Pod level?

NetworkPolicy is namespace-scoped, but it selects Pods inside that
namespace using `podSelector`. It can also use namespace selectors to
identify allowed source or destination namespaces.

### Q2. Does creating a namespace automatically isolate its Pods?

No. Namespace separation is logical. NetworkPolicy is required to
restrict Pod network traffic, and the CNI must enforce it.

### Q3. What happens if no NetworkPolicy exists?

For a Pod that is not selected by any policy for a given direction,
traffic in that direction is normally allowed, subject to the network
implementation.

### Q4. Can we deny traffic using NetworkPolicy?

NetworkPolicy is allow-list based. Once a Pod is isolated for ingress or
egress, only traffic allowed by the union of applicable policies is
permitted. There is no explicit `deny` rule.

### Q5. What happens when two NetworkPolicies select the same Pod?

Their allowed traffic is combined. The result is additive, not a
priority-based override.

### Q6. Can NetworkPolicy control traffic from outside the cluster?

It can apply to ingress or egress involving selected Pods, but exact
behavior for external addresses, node traffic, host-network Pods, and
certain special traffic depends on the CNI implementation. Validate
these cases with the chosen plugin.

### Q7. Can NetworkPolicy block traffic based on HTTP URL or hostname?

No. Standard Kubernetes NetworkPolicy operates at Layer 3/Layer 4 (IP,
protocol, and port), not HTTP URL or application-layer content.

### Q8. Does NetworkPolicy encrypt traffic?

No. It controls which traffic is allowed; it does not encrypt traffic.
Use TLS or service-mesh security where encryption is required.

### Q9. Why did DNS stop working after applying an egress policy?

Because DNS is also egress traffic. When egress is isolated, DNS traffic
must be explicitly allowed to the actual DNS Pods and ports, or another
suitable DNS path must be permitted.

### Q10. Does NetworkPolicy apply to Services or Pods?

Policies select Pods. Traffic sent to a Service is ultimately forwarded
to selected backend Pods, and enforcement details can depend on the CNI
and service implementation.

## 15. Troubleshooting checklist

If an expected connection does not work:

1.  Check that all Pods are Ready:

    ``` bash
    kubectl get pods -A -o wide
    ```

2.  Check Service selectors and endpoints:

    ``` bash
    kubectl get svc -A
    kubectl get endpointslice -A
    ```

3.  Check namespace labels:

    ``` bash
    kubectl get ns --show-labels
    ```

4.  Check Pod labels:

    ``` bash
    kubectl get pods -n frontend --show-labels
    kubectl get pods -n backend --show-labels
    kubectl get pods -n db --show-labels
    ```

5.  Check NetworkPolicies:

    ``` bash
    kubectl get networkpolicy -A
    kubectl describe networkpolicy -n frontend
    kubectl describe networkpolicy -n backend
    kubectl describe networkpolicy -n db
    ```

6.  Check DNS Pods and labels:

    ``` bash
    kubectl get pods -n kube-system --show-labels
    ```

7.  Confirm that the CNI actually enforces NetworkPolicy.

8.  Check whether the policy allows the correct protocol and destination
    port.

9.  Remember that both source egress and destination ingress policies
    must allow a connection when both sides are isolated.

A timeout is a common symptom of blocked traffic, but it is not
definitive proof of a NetworkPolicy denial. Check DNS, endpoints,
application readiness, routing, and CNI logs as well.

## 16. Cleanup

Delete the demo resources:

``` bash
kubectl delete -f 06-default-deny-db.yaml --ignore-not-found
kubectl delete -f 05-db-policy.yaml --ignore-not-found
kubectl delete -f 04-backend-policy.yaml --ignore-not-found
kubectl delete -f 03-frontend-policy.yaml --ignore-not-found
kubectl delete -f 02-applications.yaml --ignore-not-found
kubectl delete -f 01-namespaces.yaml --ignore-not-found
```

Alternatively, delete all three demo namespaces:

``` bash
kubectl delete namespace frontend backend db
```

## 17. Suggested session delivery flow

  Time         Topic
  ------------ ----------------------------------------------
  5 minutes    What is NetworkPolicy and why do we need it?
  5 minutes    Ingress vs Egress and policy behavior
  5 minutes    Create namespaces, Deployments, and Services
  5 minutes    Test connectivity before policies
  10 minutes   Apply the three NetworkPolicies
  5 minutes    Verify allowed and blocked communication
  5 minutes    Default-deny demonstration and Q&A

## 18. Closing summary

The key takeaway is that Kubernetes Network Policies help implement
zero-trust-style network segmentation between application components.

In this demo:

-   Frontend can communicate with Backend.
-   Backend can communicate with Database.
-   Frontend cannot communicate directly with Database.
-   Backend cannot communicate with Frontend.
-   Database accepts traffic only from Backend.

**Remember:** NetworkPolicy is an allow-list mechanism, policies are
additive, and enforcement depends on CNI support.
