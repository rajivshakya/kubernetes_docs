# AKS Lab: LoadBalancer Services vs Ingress with AGIC (No ACR / No Custom Docker Image)

## 1. Lab goals

This lab demonstrates two ways to expose three simple web applications
on AKS:

**Part A --- Three `LoadBalancer` Services** - Deploy three NGINX-based
websites: User, Order, and Payment. - Each website has its own
`LoadBalancer` Service and public endpoint. - Open each public IP in a
browser and show that each page is different. - Discuss why one public
endpoint per HTTP application may be inconvenient.

**Part B --- One Azure Application Gateway with AGIC** - Enable the AGIC
add-on on AKS. - Keep the same three application concepts, but expose
them internally through `ClusterIP` Services. - Create one Kubernetes
Ingress with three path rules: - `/user` → User website - `/order` →
Order website - `/payment` → Payment website - Access all three pages
using one Application Gateway public IP.

> No ACR, custom Docker image, Dockerfile, or image build is needed. The
> websites use the official `nginx` image and mount their HTML pages
> from Kubernetes ConfigMaps.

## 2. Architecture

### Part A --- Three public LoadBalancer Services

``` text
Browser
  ├── http://<USER_PUBLIC_IP>    → Azure Load Balancer → user-lb-svc    → User NGINX Pod
  ├── http://<ORDER_PUBLIC_IP>   → Azure Load Balancer → order-lb-svc   → Order NGINX Pod
  └── http://<PAYMENT_PUBLIC_IP> → Azure Load Balancer → payment-lb-svc → Payment NGINX Pod
```

### Part B --- One Application Gateway and path-based routing

``` text
Browser
  |
  | http://<APP_GATEWAY_PUBLIC_IP>/user
  | http://<APP_GATEWAY_PUBLIC_IP>/order
  | http://<APP_GATEWAY_PUBLIC_IP>/payment
  v
Azure Application Gateway
  |
  +-- /user/*    → user-svc    (ClusterIP) → User NGINX Pod
  +-- /order/*   → order-svc   (ClusterIP) → Order NGINX Pod
  +-- /payment/* → payment-svc (ClusterIP) → Payment NGINX Pod

AGIC watches Kubernetes Ingress resources and configures Application Gateway.
AGIC is the controller, not the data-plane proxy for each HTTP request.
```

## 3. Prerequisites and variables

You need: - An AKS cluster. - Azure CLI and `kubectl`. - Permission to
create Kubernetes workloads and enable the AGIC add-on. - An existing
Azure Application Gateway with a supported network configuration that
can reach the AKS backends.

This guide assumes the Application Gateway already exists. Creating or
attaching a gateway can require careful subnet and network planning; do
not create or move one into an arbitrary subnet without checking
Microsoft's current AKS/AGIC prerequisites.

Log in and set names. Replace the example values with your actual
resource names:

``` bash
az login
az account show --output table

RG="rg-aks-ingress-demo"
AKS="aks-ingress-demo"
APPGW="appgw-ingress-demo"
APPGW_RG="$RG"

az aks get-credentials --resource-group "$RG" --name "$AKS"
kubectl get nodes

az network application-gateway show \
  --resource-group "$APPGW_RG" \
  --name "$APPGW" \
  --output table
```

The shell variable examples above use Bash (Linux, macOS, or Azure Cloud
Shell). If using Windows PowerShell, define variables with
`$RG = "..."`, `$AKS = "..."`, and so on.

## 4. Part A --- Deploy three NGINX websites with LoadBalancer Services

We will create three separate Deployments. Each Pod uses the official
`nginx` image. A ConfigMap provides the HTML content, mounted at
`/usr/share/nginx/html/index.html`.

The pages are intentionally different: - **User website:** customer
profile and account. - **Order website:** order history and tracking. -
**Payment website:** checkout and payment status (demo only; no real
payments).

Create a file named `01-loadbalancer-websites.yaml`:

``` yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: user-web
data:
  index.html: |
    <!doctype html>
    <html>
    <head>
      <meta charset="utf-8">
      <title>User Service</title>
      <style>
        body { font-family: Arial, sans-serif; background: #f3e8ff; margin: 0; }
        header { background: #7c3aed; color: white; padding: 28px; }
        main { margin: 35px auto; max-width: 760px; background: white; padding: 28px; border-radius: 12px; }
        .tag { display: inline-block; background: #ede9fe; padding: 8px 12px; border-radius: 8px; }
      </style>
    </head>
    <body>
      <header><h1>User Service</h1><p>E-commerce customer account</p></header>
      <main>
        <h2>Welcome, Customer!</h2>
        <p>This is the <strong>User</strong> application running on Kubernetes.</p>
        <p class="tag">Feature: Profile, address book, and account settings</p>
        <p>Demo endpoint: /user</p>
      </main>
    </body>
    </html>
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: user-lb
  labels:
    app: user-lb
spec:
  replicas: 2
  selector:
    matchLabels:
      app: user-lb
  template:
    metadata:
      labels:
        app: user-lb
    spec:
      containers:
        - name: nginx
          image: nginx:stable
          ports:
            - containerPort: 80
          volumeMounts:
            - name: web-content
              mountPath: /usr/share/nginx/html/index.html
              subPath: index.html
              readOnly: true
          readinessProbe:
            httpGet:
              path: /
              port: 80
            initialDelaySeconds: 2
            periodSeconds: 5
          resources:
            requests:
              cpu: 50m
              memory: 32Mi
            limits:
              cpu: 200m
              memory: 64Mi
      volumes:
        - name: web-content
          configMap:
            name: user-web
---
apiVersion: v1
kind: Service
metadata:
  name: user-lb-svc
spec:
  type: LoadBalancer
  selector:
    app: user-lb
  ports:
    - name: http
      port: 80
      targetPort: 80
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: order-web
data:
  index.html: |
    <!doctype html>
    <html>
    <head>
      <meta charset="utf-8">
      <title>Order Service</title>
      <style>
        body { font-family: Arial, sans-serif; background: #dbeafe; margin: 0; }
        header { background: #2563eb; color: white; padding: 28px; }
        main { margin: 35px auto; max-width: 760px; background: white; padding: 28px; border-radius: 12px; }
        .tag { display: inline-block; background: #dbeafe; padding: 8px 12px; border-radius: 8px; }
      </style>
    </head>
    <body>
      <header><h1>Order Service</h1><p>E-commerce order centre</p></header>
      <main>
        <h2>Your Orders</h2>
        <p>This is the <strong>Order</strong> application running on Kubernetes.</p>
        <p class="tag">Feature: Order history, delivery tracking, and returns</p>
        <p>Demo endpoint: /order</p>
      </main>
    </body>
    </html>
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: order-lb
  labels:
    app: order-lb
spec:
  replicas: 2
  selector:
    matchLabels:
      app: order-lb
  template:
    metadata:
      labels:
        app: order-lb
    spec:
      containers:
        - name: nginx
          image: nginx:stable
          ports:
            - containerPort: 80
          volumeMounts:
            - name: web-content
              mountPath: /usr/share/nginx/html/index.html
              subPath: index.html
              readOnly: true
          readinessProbe:
            httpGet:
              path: /
              port: 80
            initialDelaySeconds: 2
            periodSeconds: 5
          resources:
            requests:
              cpu: 50m
              memory: 32Mi
            limits:
              cpu: 200m
              memory: 64Mi
      volumes:
        - name: web-content
          configMap:
            name: order-web
---
apiVersion: v1
kind: Service
metadata:
  name: order-lb-svc
spec:
  type: LoadBalancer
  selector:
    app: order-lb
  ports:
    - name: http
      port: 80
      targetPort: 80
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: payment-web
data:
  index.html: |
    <!doctype html>
    <html>
    <head>
      <meta charset="utf-8">
      <title>Payment Service</title>
      <style>
        body { font-family: Arial, sans-serif; background: #dcfce7; margin: 0; }
        header { background: #15803d; color: white; padding: 28px; }
        main { margin: 35px auto; max-width: 760px; background: white; padding: 28px; border-radius: 12px; }
        .tag { display: inline-block; background: #dcfce7; padding: 8px 12px; border-radius: 8px; }
      </style>
    </head>
    <body>
      <header><h1>Payment Service</h1><p>E-commerce checkout</p></header>
      <main>
        <h2>Payment Status: Demo Mode</h2>
        <p>This is the <strong>Payment</strong> application running on Kubernetes.</p>
        <p class="tag">Feature: Checkout and payment status (no real transactions)</p>
        <p>Demo endpoint: /payment</p>
      </main>
    </body>
    </html>
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: payment-lb
  labels:
    app: payment-lb
spec:
  replicas: 2
  selector:
    matchLabels:
      app: payment-lb
  template:
    metadata:
      labels:
        app: payment-lb
    spec:
      containers:
        - name: nginx
          image: nginx:stable
          ports:
            - containerPort: 80
          volumeMounts:
            - name: web-content
              mountPath: /usr/share/nginx/html/index.html
              subPath: index.html
              readOnly: true
          readinessProbe:
            httpGet:
              path: /
              port: 80
            initialDelaySeconds: 2
            periodSeconds: 5
          resources:
            requests:
              cpu: 50m
              memory: 32Mi
            limits:
              cpu: 200m
              memory: 64Mi
      volumes:
        - name: web-content
          configMap:
            name: payment-web
---
apiVersion: v1
kind: Service
metadata:
  name: payment-lb-svc
spec:
  type: LoadBalancer
  selector:
    app: payment-lb
  ports:
    - name: http
      port: 80
      targetPort: 80
```

Apply the manifest:

``` bash
kubectl apply -f 01-loadbalancer-websites.yaml
kubectl get deployments
kubectl get pods -o wide
kubectl get svc user-lb-svc order-lb-svc payment-lb-svc --watch
```

Wait until all three Services show an external IP rather than
`<pending>`. In a second terminal, you can check:

``` bash
kubectl get svc user-lb-svc order-lb-svc payment-lb-svc
```

Open the pages in a browser:

``` text
http://<USER_EXTERNAL_IP>
http://<ORDER_EXTERNAL_IP>
http://<PAYMENT_EXTERNAL_IP>
```

Or use `curl`:

``` bash
curl -i http://<USER_EXTERNAL_IP>
curl -i http://<ORDER_EXTERNAL_IP>
curl -i http://<PAYMENT_EXTERNAL_IP>
```

Expected results: - The User page has a purple header and customer
account content. - The Order page has a blue header and order history
content. - The Payment page has a green header and demo payment status
content.

> Note: The official NGINX image must be pulled from its public
> registry, so the cluster needs a working path to the image registry.
> This lab avoids ACR and custom image builds.

## 5. Explain the drawbacks of three LoadBalancer Services

Use this table while teaching:

  -----------------------------------------------------------------------
  Topic                               Three LoadBalancer Services
  ----------------------------------- -----------------------------------
  Public entry points                 Typically one externally exposed
                                      Service endpoint per app

  URL structure                       Separate IPs or DNS names,
                                      e.g. `user.example.com`,
                                      `order.example.com`,
                                      `payment.example.com`

  Path routing                        A basic Service does not route HTTP
                                      paths such as `/user` and `/order`

  TLS/HTTPS                           Certificates and HTTPS
                                      configuration may be repeated
                                      unless another layer centralizes
                                      them

  Security operations                 More public endpoints to govern,
                                      monitor, and review

  Cost/overhead                       Public IPs and load-balancing
                                      rules/resources can add cost or
                                      operational overhead
  -----------------------------------------------------------------------

**Important nuance:** A Kubernetes `LoadBalancer` Service requests an
external Layer 4 endpoint. In Azure, implementation details vary and
multiple Services may share underlying Azure Load Balancer
infrastructure or frontend configuration. Therefore, do not teach that
every Service must always create a completely separate Azure Load
Balancer resource. The main teaching point is that each Service is
separately exposed, and a basic Service does not provide HTTP path-based
routing.

Also explain that LoadBalancer Services are not wrong: they remain
useful for workloads that need their own external Layer 4 endpoint,
including certain TCP/UDP applications. For many HTTP/HTTPS websites, a
shared Layer 7 gateway can be more convenient.

## 6. Part B --- Enable AGIC on AKS

### 6.1 Check the existing Application Gateway

``` bash
az network application-gateway show \
  --resource-group "$APPGW_RG" \
  --name "$APPGW" \
  --query "{name:name,sku:sku.name,state:operationalState}" \
  --output json
```

Check AKS networking:

``` bash
az aks show \
  --resource-group "$RG" \
  --name "$AKS" \
  --query "networkProfile" \
  --output json
```

The Application Gateway must use a supported network setup and be able
to reach the AKS backend endpoints. Confirm the correct subnet, VNet
connectivity, permissions, and supported AKS networking configuration
before enabling the add-on.

### 6.2 Enable the AGIC add-on

If Application Gateway is in the same resource group as AKS:

``` bash
az aks enable-addons \
  --resource-group "$RG" \
  --name "$AKS" \
  --addons ingress-appgw \
  --appgw-name "$APPGW" \
  --appgw-resource-group "$APPGW_RG"
```

If the gateway is in a different resource group, keep `APPGW_RG` set to
that resource group's name. This command assumes an existing compatible
Application Gateway. Follow the current Microsoft AKS AGIC documentation
if your cluster/gateway setup requires a different configuration.

Verify the add-on:

``` bash
az aks show \
  --resource-group "$RG" \
  --name "$AKS" \
  --query "addonProfiles.ingressApplicationGateway" \
  --output json

kubectl get pods -A
```

AGIC watches Kubernetes Ingress resources and configures Azure
Application Gateway. The gateway handles incoming HTTP requests. AGIC is
not normally a Pod that forwards every request.

## 7. Part C --- Replace the public Services with ClusterIP Services and create Ingress rules

For a clean classroom demonstration, remove the Part A workloads before
applying the new manifest. This avoids keeping three old public
endpoints running alongside the Ingress demo:

``` bash
kubectl delete -f 01-loadbalancer-websites.yaml
```

Now create `02-agic-ingress-websites.yaml`. The same official NGINX
image is used, but each application is exposed internally by a
`ClusterIP` Service. Each HTML page is stored in a ConfigMap.

``` yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: user-web
data:
  index.html: |
    <!doctype html>
    <html><head><meta charset="utf-8"><title>User Service</title>
    <style>body{font-family:Arial;background:#f3e8ff;margin:0}header{background:#7c3aed;color:white;padding:28px}main{margin:35px auto;max-width:760px;background:white;padding:28px;border-radius:12px}</style>
    </head><body><header><h1>User Service</h1><p>Customer account</p></header>
    <main><h2>Welcome, Customer!</h2><p>Profile, address book, and account settings.</p><p>Ingress route: /user</p></main></body></html>
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: user-app
  labels:
    app: user-app
spec:
  replicas: 2
  selector:
    matchLabels:
      app: user-app
  template:
    metadata:
      labels:
        app: user-app
    spec:
      containers:
        - name: nginx
          image: nginx:stable
          ports:
            - containerPort: 80
          volumeMounts:
            - name: web-content
              mountPath: /usr/share/nginx/html/index.html
              subPath: index.html
              readOnly: true
          readinessProbe:
            httpGet:
              path: /
              port: 80
            initialDelaySeconds: 2
            periodSeconds: 5
          resources:
            requests:
              cpu: 50m
              memory: 32Mi
            limits:
              cpu: 200m
              memory: 64Mi
      volumes:
        - name: web-content
          configMap:
            name: user-web
---
apiVersion: v1
kind: Service
metadata:
  name: user-svc
spec:
  type: ClusterIP
  selector:
    app: user-app
  ports:
    - name: http
      port: 80
      targetPort: 80
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: order-web
data:
  index.html: |
    <!doctype html>
    <html><head><meta charset="utf-8"><title>Order Service</title>
    <style>body{font-family:Arial;background:#dbeafe;margin:0}header{background:#2563eb;color:white;padding:28px}main{margin:35px auto;max-width:760px;background:white;padding:28px;border-radius:12px}</style>
    </head><body><header><h1>Order Service</h1><p>Order centre</p></header>
    <main><h2>Your Orders</h2><p>Order history, delivery tracking, and returns.</p><p>Ingress route: /order</p></main></body></html>
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: order-app
  labels:
    app: order-app
spec:
  replicas: 2
  selector:
    matchLabels:
      app: order-app
  template:
    metadata:
      labels:
        app: order-app
    spec:
      containers:
        - name: nginx
          image: nginx:stable
          ports:
            - containerPort: 80
          volumeMounts:
            - name: web-content
              mountPath: /usr/share/nginx/html/index.html
              subPath: index.html
              readOnly: true
          readinessProbe:
            httpGet:
              path: /
              port: 80
            initialDelaySeconds: 2
            periodSeconds: 5
          resources:
            requests:
              cpu: 50m
              memory: 32Mi
            limits:
              cpu: 200m
              memory: 64Mi
      volumes:
        - name: web-content
          configMap:
            name: order-web
---
apiVersion: v1
kind: Service
metadata:
  name: order-svc
spec:
  type: ClusterIP
  selector:
    app: order-app
  ports:
    - name: http
      port: 80
      targetPort: 80
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: payment-web
data:
  index.html: |
    <!doctype html>
    <html><head><meta charset="utf-8"><title>Payment Service</title>
    <style>body{font-family:Arial;background:#dcfce7;margin:0}header{background:#15803d;color:white;padding:28px}main{margin:35px auto;max-width:760px;background:white;padding:28px;border-radius:12px}</style>
    </head><body><header><h1>Payment Service</h1><p>Checkout</p></header>
    <main><h2>Payment Status: Demo Mode</h2><p>Checkout and payment-status page. No real transactions are processed.</p><p>Ingress route: /payment</p></main></body></html>
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: payment-app
  labels:
    app: payment-app
spec:
  replicas: 2
  selector:
    matchLabels:
      app: payment-app
  template:
    metadata:
      labels:
        app: payment-app
    spec:
      containers:
        - name: nginx
          image: nginx:stable
          ports:
            - containerPort: 80
          volumeMounts:
            - name: web-content
              mountPath: /usr/share/nginx/html/index.html
              subPath: index.html
              readOnly: true
          readinessProbe:
            httpGet:
              path: /
              port: 80
            initialDelaySeconds: 2
            periodSeconds: 5
          resources:
            requests:
              cpu: 50m
              memory: 32Mi
            limits:
              cpu: 200m
              memory: 64Mi
      volumes:
        - name: web-content
          configMap:
            name: payment-web
---
apiVersion: v1
kind: Service
metadata:
  name: payment-svc
spec:
  type: ClusterIP
  selector:
    app: payment-app
  ports:
    - name: http
      port: 80
      targetPort: 80
---
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: ecommerce-ingress
spec:
  ingressClassName: azure-application-gateway
  rules:
    - http:
        paths:
          - path: /user
            pathType: Prefix
            backend:
              service:
                name: user-svc
                port:
                  number: 80
          - path: /order
            pathType: Prefix
            backend:
              service:
                name: order-svc
                port:
                  number: 80
          - path: /payment
            pathType: Prefix
            backend:
              service:
                name: payment-svc
                port:
                  number: 80
```

Apply and inspect:

``` bash
kubectl apply -f 02-agic-ingress-websites.yaml

kubectl get deployments
kubectl get pods -o wide
kubectl get svc user-svc order-svc payment-svc
kubectl get ingress ecommerce-ingress
kubectl describe ingress ecommerce-ingress
kubectl get events --sort-by=.metadata.creationTimestamp
```

Wait for AGIC to reconcile the Ingress and configure Application
Gateway. The `ingressClassName` shown above is for the AKS AGIC add-on;
if your cluster uses a different AGIC deployment/configuration, confirm
its configured ingress class.

## 8. Find the Application Gateway public IP

Retrieve the public IP resource ID from the gateway:

``` bash
az network application-gateway show \
  --resource-group "$APPGW_RG" \
  --name "$APPGW" \
  --query "frontendIPConfigurations[].publicIPAddress.id" \
  --output tsv
```

Copy the returned resource ID and query its IP address:

``` bash
PUBLIC_IP_ID="<paste-public-ip-resource-id-here>"

az network public-ip show \
  --ids "$PUBLIC_IP_ID" \
  --query "ipAddress" \
  --output tsv
```

If the gateway uses a private frontend only, you will not be able to
access it from the public internet. Use the correct reachable frontend
IP for your environment.

Open these URLs:

``` text
http://<APP_GATEWAY_PUBLIC_IP>/user
http://<APP_GATEWAY_PUBLIC_IP>/order
http://<APP_GATEWAY_PUBLIC_IP>/payment
```

Test with curl:

``` bash
curl -i http://<APP_GATEWAY_PUBLIC_IP>/user
curl -i http://<APP_GATEWAY_PUBLIC_IP>/order
curl -i http://<APP_GATEWAY_PUBLIC_IP>/payment
```

The three paths should display different page titles, content, and
colours.

## 9. Explain the traffic flow

For a request to `/order`:

1.  The browser sends a request to the public IP of Azure Application
    Gateway with the path `/order`.
2.  Application Gateway evaluates the path-based rule configured from
    the Kubernetes Ingress.
3.  Application Gateway forwards the request to the backend associated
    with `order-svc`.
4.  Kubernetes Service networking sends traffic to a ready `order-app`
    Pod.
5.  The NGINX Pod serves the Order HTML page, and the response returns
    through Application Gateway.

**Remember:** AGIC watches and translates Kubernetes configuration into
Application Gateway configuration. Application Gateway processes the
actual incoming HTTP traffic.

## 10. Troubleshooting

``` bash
# Pod status
kubectl get pods -o wide

# Deployment and Pod details
kubectl describe deployment user-app
kubectl describe pod <POD_NAME>

# NGINX logs
kubectl logs deployment/user-app
kubectl logs deployment/order-app
kubectl logs deployment/payment-app

# Service endpoints
kubectl get svc
kubectl get endpointslices

# Ingress details and recent events
kubectl describe ingress ecommerce-ingress
kubectl get events --sort-by=.metadata.creationTimestamp

# AGIC add-on state
az aks show -g "$RG" -n "$AKS" \
  --query "addonProfiles.ingressApplicationGateway" -o json

# Application Gateway backend health
az network application-gateway show-backend-health \
  --resource-group "$APPGW_RG" \
  --name "$APPGW" \
  --output json
```

Common issues:

-   **LoadBalancer IP remains `<pending>`:** check Azure permissions,
    IP/subnet quotas, and Service events.
-   **Pods are `ImagePullBackOff`:** check cluster outbound access to
    the public container registry and the image tag.
-   **Application Gateway returns 502:** check backend health,
    VNet/subnet connectivity, network security rules, Pod readiness, and
    Service ports.
-   **Ingress is not reflected in the gateway:** verify AGIC add-on
    status, the `ingressClassName`, Ingress events, and gateway
    permissions.
-   **A route returns 404:** verify the path and the backend. In this
    lab each page is mounted as NGINX's root `index.html`; Application
    Gateway routes the original path to the selected backend. NGINX may
    look for a directory for paths such as `/order`. If this happens,
    use the URL rewrite configuration supported by your AGIC/Application
    Gateway version to rewrite the backend path to `/`, or change the
    lab to use dedicated root-path hostnames. Test this behaviour in
    your environment before class.

### Optional note on path rewriting

The Ingress above demonstrates path selection, but Application Gateway
normally forwards the URL path unless a rewrite is configured. NGINX's
default static-site configuration can return 404 for `/order` because it
tries to find an `order` path under the web root. If you need the three
URLs to show the page without a 404, configure a supported Application
Gateway rewrite rule to change the backend path to `/` for each path
rule, or use host-based routing (for example, `user.demo.example`,
`order.demo.example`, and `payment.demo.example`). The exact rewrite
setup depends on the Application Gateway/AGIC version and configuration.
Validate it before the session.

## 11. Clean up

Remove the Ingress demo resources when finished:

``` bash
kubectl delete -f 02-agic-ingress-websites.yaml
```

This deletes the Kubernetes demo resources, not the AKS cluster or
Application Gateway. Do not delete shared Azure infrastructure unless
you have confirmed it is dedicated to this lab.

## 12. Instructor wrap-up

-   `LoadBalancer` Service exposes an application through an external
    Layer 4 endpoint.
-   Using multiple LoadBalancer Services can mean multiple public entry
    points to manage.
-   Ingress provides Layer 7 HTTP/HTTPS routing by host or path.
-   With AKS AGIC, Azure Application Gateway is the traffic entry point;
    AGIC configures it based on Kubernetes resources.
-   The Ingress version uses internal `ClusterIP` Services behind one
    gateway endpoint.
-   In production, consider HTTPS/TLS, DNS, WAF policy, backend health,
    network isolation, identity/RBAC, monitoring, and cost.
