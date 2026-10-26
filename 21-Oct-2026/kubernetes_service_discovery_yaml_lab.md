# Kubernetes Service Discovery Across Namespaces

## YAML-Based Hands-on Lab Guide

**Objective:** Demonstrate Service discovery within the same namespace
and across different namespaces using Kubernetes DNS.

This lab creates three namespaces: - `frontend`: two application
Deployments and two Services - `backend`: one Deployment and one
Service - `db`: one Deployment and one Service

A temporary `dns-client` Pod runs in the `frontend` namespace to test
DNS and HTTP connectivity.

> **Important:** The `db` workload uses NGINX only as a simple HTTP
> endpoint for this DNS lab. It is not a real database.

> **Cluster DNS domain:** Examples assume `cluster.local`, which is
> common but not universal. Replace it if your cluster uses another
> domain.

------------------------------------------------------------------------

## 1. Architecture

``` text
Kubernetes Cluster
|
+-- Namespace: frontend
|   +-- frontend-app-1 Deployment / Pod
|   +-- frontend-svc-1 Service
|   +-- frontend-app-2 Deployment / Pod
|   +-- frontend-svc-2 Service
|   +-- dns-client Pod (testing)
|
+-- Namespace: backend
|   +-- backend-app Deployment / Pod
|   +-- backend-svc Service
|
+-- Namespace: db
    +-- db-app Deployment / Pod
    +-- db-svc Service
```

### Expected discovery behavior from `dns-client` in `frontend`

  Destination                     Name to use
  ------------------------------- -----------------------------------------
  Service in `frontend`           `frontend-svc-1`
  Another Service in `frontend`   `frontend-svc-2`
  Service in `backend`            `backend-svc.backend`
  Service in `db`                 `db-svc.db`
  Full backend Service FQDN       `backend-svc.backend.svc.cluster.local`

A normal ClusterIP Service's DNS name resolves to its ClusterIP. The
Kubernetes Service data plane then routes traffic to a ready endpoint.

------------------------------------------------------------------------

## 2. Create the lab directory

``` bash
mkdir -p service-discovery-lab
cd service-discovery-lab
```

Create the following files in this directory.

------------------------------------------------------------------------

## 3. Namespace YAML

Save as `01-namespaces.yaml`:

``` yaml
apiVersion: v1
kind: Namespace
metadata:
  name: frontend
---
apiVersion: v1
kind: Namespace
metadata:
  name: backend
---
apiVersion: v1
kind: Namespace
metadata:
  name: db
```

Apply and verify:

``` bash
kubectl apply -f 01-namespaces.yaml
kubectl get namespaces frontend backend db
```

------------------------------------------------------------------------

## 4. Frontend Deployment and Services YAML

Save as `02-frontend.yaml`:

``` yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: frontend-app-1
  namespace: frontend
spec:
  replicas: 1
  selector:
    matchLabels:
      app: frontend-app-1
  template:
    metadata:
      labels:
        app: frontend-app-1
    spec:
      containers:
        - name: nginx
          image: nginx:1.27
          ports:
            - name: http
              containerPort: 80
---
apiVersion: v1
kind: Service
metadata:
  name: frontend-svc-1
  namespace: frontend
spec:
  type: ClusterIP
  selector:
    app: frontend-app-1
  ports:
    - name: http
      port: 80
      targetPort: http
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: frontend-app-2
  namespace: frontend
spec:
  replicas: 1
  selector:
    matchLabels:
      app: frontend-app-2
  template:
    metadata:
      labels:
        app: frontend-app-2
    spec:
      containers:
        - name: nginx
          image: nginx:1.27
          ports:
            - name: http
              containerPort: 80
---
apiVersion: v1
kind: Service
metadata:
  name: frontend-svc-2
  namespace: frontend
spec:
  type: ClusterIP
  selector:
    app: frontend-app-2
  ports:
    - name: http
      port: 80
      targetPort: http
```

Apply and verify:

``` bash
kubectl apply -f 02-frontend.yaml
kubectl get deployments,pods,services -n frontend
kubectl get endpoints -n frontend
kubectl get endpointslices -n frontend
```

------------------------------------------------------------------------

## 5. Backend Deployment and Service YAML

Save as `03-backend.yaml`:

``` yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: backend-app
  namespace: backend
spec:
  replicas: 1
  selector:
    matchLabels:
      app: backend-app
  template:
    metadata:
      labels:
        app: backend-app
    spec:
      containers:
        - name: nginx
          image: nginx:1.27
          ports:
            - name: http
              containerPort: 80
---
apiVersion: v1
kind: Service
metadata:
  name: backend-svc
  namespace: backend
spec:
  type: ClusterIP
  selector:
    app: backend-app
  ports:
    - name: http
      port: 80
      targetPort: http
```

Apply and verify:

``` bash
kubectl apply -f 03-backend.yaml
kubectl get deployments,pods,services -n backend
kubectl get endpoints backend-svc -n backend
```

------------------------------------------------------------------------

## 6. Database-namespace Deployment and Service YAML

For this lab, NGINX acts as a test HTTP endpoint. Save as `04-db.yaml`:

``` yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: db-app
  namespace: db
spec:
  replicas: 1
  selector:
    matchLabels:
      app: db-app
  template:
    metadata:
      labels:
        app: db-app
    spec:
      containers:
        - name: nginx
          image: nginx:1.27
          ports:
            - name: http
              containerPort: 80
---
apiVersion: v1
kind: Service
metadata:
  name: db-svc
  namespace: db
spec:
  type: ClusterIP
  selector:
    app: db-app
  ports:
    - name: http
      port: 80
      targetPort: http
```

Apply and verify:

``` bash
kubectl apply -f 04-db.yaml
kubectl get deployments,pods,services -n db
kubectl get endpoints db-svc -n db
```

------------------------------------------------------------------------

## 7. Test client Pod YAML

Save as `05-dns-client.yaml`:

``` yaml
apiVersion: v1
kind: Pod
metadata:
  name: dns-client
  namespace: frontend
  labels:
    app: dns-client
spec:
  restartPolicy: Never
  containers:
    - name: client
      image: busybox:1.36
      command:
        - sh
        - -c
        - sleep 3600
```

Apply and wait:

``` bash
kubectl apply -f 05-dns-client.yaml
kubectl get pod dns-client -n frontend
kubectl wait --for=condition=Ready pod/dns-client -n frontend --timeout=120s
```

Wait for all application Deployments:

``` bash
kubectl rollout status deployment/frontend-app-1 -n frontend
kubectl rollout status deployment/frontend-app-2 -n frontend
kubectl rollout status deployment/backend-app -n backend
kubectl rollout status deployment/db-app -n db
```

------------------------------------------------------------------------

## 8. Same-namespace discovery tests

Run the commands inside the test Pod:

``` bash
kubectl exec -it dns-client -n frontend -- sh
```

Inside the shell:

``` sh
nslookup frontend-svc-1
wget -qO- -T 5 http://frontend-svc-1
```

Then:

``` sh
nslookup frontend-svc-2
wget -qO- -T 5 http://frontend-svc-2
```

### Expected result

-   DNS resolves each Service name.
-   `wget` returns the NGINX welcome page HTML.
-   Because the client and both Services are in `frontend`, the short
    Service name is sufficient.

------------------------------------------------------------------------

## 9. Cross-namespace discovery tests

Still inside the `dns-client` shell, first try the short name:

``` sh
nslookup backend-svc
```

This normally fails because `backend-svc` is searched in the client's
`frontend` namespace, while the Service exists in `backend`.

Now use the Service name and namespace:

``` sh
nslookup backend-svc.backend
wget -qO- -T 5 http://backend-svc.backend
```

Test the `db` namespace:

``` sh
nslookup db-svc.db
wget -qO- -T 5 http://db-svc.db
```

### Expected result

-   `backend-svc.backend` resolves to the backend Service's ClusterIP
    and HTTP works.
-   `db-svc.db` resolves to the db-namespace Service's ClusterIP and
    HTTP works.

------------------------------------------------------------------------

## 10. Test the full Service FQDN

For a cluster using the `cluster.local` DNS domain:

``` sh
nslookup backend-svc.backend.svc.cluster.local
wget -qO- -T 5 http://backend-svc.backend.svc.cluster.local
```

For the `db` Service:

``` sh
nslookup db-svc.db.svc.cluster.local
wget -qO- -T 5 http://db-svc.db.svc.cluster.local
```

General pattern:

``` text
<service-name>.<namespace>.svc.<cluster-domain>
```

Exit the Pod shell:

``` sh
exit
```

------------------------------------------------------------------------

## 11. Inspect DNS configuration

View the resolver configuration in the test Pod:

``` bash
kubectl exec dns-client -n frontend -- cat /etc/resolv.conf
```

A typical example:

``` text
nameserver 10.96.0.10
search frontend.svc.cluster.local svc.cluster.local cluster.local
options ndots:5
```

The nameserver IP and search list vary by cluster. Explain:

-   `nameserver`: DNS resolver used by the Pod.
-   `search`: suffixes used to expand short names.
-   `ndots`: affects when the resolver tries search suffixes versus
    querying a name as-is.

------------------------------------------------------------------------

## 12. Explain the packet flow

``` text
dns-client Pod (frontend namespace)
       |
       | DNS query: backend-svc.backend
       v
     CoreDNS
       |
       | Returns backend Service ClusterIP
       v
  backend-svc ClusterIP
       |
       | Service data plane routes traffic
       v
  Ready backend Pod endpoint
```

Key points:

1.  **Service discovery:** CoreDNS resolves the Service name to its
    ClusterIP.
2.  **Traffic routing:** The Kubernetes Service data plane forwards
    traffic to a ready endpoint. This is commonly kube-proxy with
    iptables/IPVS, but some clusters use CNI/eBPF implementations.
3.  **Namespaces:** Namespace-scoped names prevent ambiguous short
    names. A namespace alone does not block network traffic;
    NetworkPolicies or other network controls may restrict it.

------------------------------------------------------------------------

## 13. Troubleshooting

### Check Pods, Services, and endpoints

``` bash
kubectl get pods,svc -n frontend
kubectl get pods,svc -n backend
kubectl get pods,svc -n db
kubectl get endpoints -n frontend
kubectl get endpoints -n backend
kubectl get endpoints -n db
```

### If DNS fails

``` bash
kubectl get pods -n kube-system
kubectl get svc -n kube-system kube-dns
kubectl logs -n kube-system deployment/coredns
```

The CoreDNS Deployment name may vary by Kubernetes distribution.

### If DNS works but HTTP fails

``` bash
kubectl describe svc backend-svc -n backend
kubectl get endpoints backend-svc -n backend
kubectl get pods -n backend --show-labels
```

Confirm that: - Service selectors match Pod labels. - Pods are Ready. -
`port` and `targetPort` match the application listener. -
NetworkPolicies or other network controls do not block the traffic.

### If FQDN fails

Check the actual cluster DNS domain. `cluster.local` is common but not
guaranteed.

------------------------------------------------------------------------

## 14. Quick command-line overview

``` bash
kubectl get svc -A
kubectl get endpoints -A
kubectl get endpointslices -A
kubectl get pods -A -o wide
```

------------------------------------------------------------------------

## 15. Cleanup

**Warning:** This deletes every resource in these three namespaces. Use
only if they are dedicated to this lab.

``` bash
kubectl delete namespace frontend backend db
```

------------------------------------------------------------------------

## 16. Session recap

  ------------------------------------------------------------------------------------
  Scenario                            Example
  ----------------------------------- ------------------------------------------------
  Same namespace                      `http://frontend-svc-1`

  Different namespace                 `http://backend-svc.backend`

  Full FQDN                           `http://backend-svc.backend.svc.cluster.local`

  DNS resolver in a typical cluster   CoreDNS

  Typical DNS result for a ClusterIP  Service ClusterIP
  Service                             

  Component that routes Service       Kubernetes Service data plane
  traffic                             
  ------------------------------------------------------------------------------------

**Closing statement:** A Pod can usually discover a Service in its own
namespace by the short Service name. For a Service in another namespace,
use the Service name with the namespace, or use the full Service FQDN.
CoreDNS resolves the name; the Kubernetes Service data plane routes the
traffic to a backend endpoint.
