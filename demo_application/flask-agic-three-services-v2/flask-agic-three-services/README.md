# Flask 3 Microservices + AKS + AGIC demo

A deliberately small demo with three independent Flask services:

- `/user` -> `user-service`
- `/order` -> `order-service`
- `/payment` -> `payment-service`

Each service is built as a separate Docker image, runs in its own Deployment/Pod, and is exposed internally through a Kubernetes `ClusterIP` Service. AGIC configures Application Gateway path-based routing.

## Architecture

```text
Browser
   |
   v
Azure Application Gateway (public frontend)
   |
   | AGIC-managed path routing
   +---- /user    ----> user-service ClusterIP ----> user-service Pod
   +---- /order   ----> order-service ClusterIP ---> order-service Pod
   +---- /payment ----> payment-service ClusterIP -> payment-service Pod
```

## 1. Build and push images (Windows PowerShell)

Prerequisites: Azure CLI, Docker Desktop, an existing ACR, and `az login`.

From the project root:

```powershell
.\scripts\build-push.ps1 -AcrName apkirasoi
```

This creates and pushes:
- `<ACR_LOGIN_SERVER>/user-service:v1`
- `<ACR_LOGIN_SERVER>/order-service:v1`
- `<ACR_LOGIN_SERVER>/payment-service:v1`

Linux/macOS alternative:

```bash
chmod +x scripts/build-push.sh
./scripts/build-push.sh apkirasoi
```

## 2. Connect to AKS

```bash
az aks get-credentials --resource-group <AKS_RESOURCE_GROUP> --name <AKS_CLUSTER_NAME>
kubectl get nodes
```

Make sure AKS can pull from ACR. If it is not already attached:

```bash
az aks update --resource-group <AKS_RESOURCE_GROUP> --name <AKS_CLUSTER_NAME> --attach-acr apkirasoi
```

Use the actual ACR resource name. The command requires suitable Azure permissions.

## 3. Set image registry in Kubernetes YAML

Get the exact ACR login server:

```bash
az acr show --name apkirasoi --query loginServer -o tsv
```

Open `k8s/three-services.yaml` and replace all occurrences of:

```text
<ACR_LOGIN_SERVER>
```

with the returned value, for example `apkirasoi.azurecr.io`.

## 4. Deploy the three services

```bash
kubectl apply -f k8s/three-services.yaml
kubectl get deployments
kubectl get pods
kubectl get svc
```

Wait until all three pods are Ready:

```bash
kubectl rollout status deployment/user-service
kubectl rollout status deployment/order-service
kubectl rollout status deployment/payment-service
```

## 5. Deploy AGIC Ingress

Prerequisites:
- Application Gateway exists and is integrated with this AKS cluster through the AGIC add-on or a supported AGIC installation.
- AGIC identity and network permissions are configured.
- The IngressClass `azure-application-gateway` is supported by the installed AGIC setup.

Apply:

```bash
kubectl apply -f k8s/ingress-agic.yaml
kubectl get ingress
kubectl describe ingress demo-agic-ingress
```

Find the Application Gateway public IP:

```bash
az network public-ip list --resource-group <APP_GATEWAY_RESOURCE_GROUP> --query "[].{name:name,ip:ipAddress}" -o table
```

Open these URLs, replacing `<APP_GATEWAY_PUBLIC_IP>`:

```text
http://<APP_GATEWAY_PUBLIC_IP>/user
http://<APP_GATEWAY_PUBLIC_IP>/order
http://<APP_GATEWAY_PUBLIC_IP>/payment
```

If you use a DNS name, create an A record pointing to the Application Gateway public IP.

## 6. Troubleshooting commands

```bash
kubectl get pods -o wide
kubectl get svc
kubectl get ingress
kubectl describe ingress demo-agic-ingress
kubectl logs deployment/user-service
kubectl logs deployment/order-service
kubectl logs deployment/payment-service
```

Check each backend from inside the cluster:

```bash
kubectl run curl-test --image=curlimages/curl:8.10.1 -it --rm --restart=Never -- \
  curl -i http://user-service/health
```

Repeat with `order-service` and `payment-service`.

## Notes

- This demo uses three separate microservice Deployments and ClusterIP Services, not one Flask app with three routes. This makes AGIC path-based routing visible in the demo.
- Each service responds on its own route and exposes `/health` for Kubernetes probes and Application Gateway health probing.
- No database or business logic is included; each service returns a simple page to keep the demo easy to explain.
- The Docker image uses Gunicorn to serve Flask. Flask's built-in development server is not used for the container runtime.
- Application Gateway and AGIC must already be configured correctly; this project provides Kubernetes Ingress configuration, not the Azure infrastructure provisioning.
