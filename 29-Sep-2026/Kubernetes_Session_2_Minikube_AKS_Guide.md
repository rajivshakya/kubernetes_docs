# Kubernetes Session 2: Installation on Azure VM with Minikube and AKS Cluster Deployment

## Session Objectives

By the end of this session, participants will be able to:

1.  Identify the different environments in which Kubernetes can run.
2.  Explain the difference between self-managed Kubernetes and managed
    Kubernetes services.
3.  Prepare an Azure Linux VM and install Minikube using Docker.
4.  Start a local Kubernetes cluster, verify its components, and deploy
    a sample application.
5.  Provision an Azure Kubernetes Service (AKS) cluster using the Azure
    CLI.
6.  Connect to AKS, deploy a sample workload, expose it, and clean up
    resources.

> **Important:** Minikube is intended mainly for learning, development,
> and testing. AKS is a managed Kubernetes service intended for cloud
> workloads. Commands below assume an Ubuntu Linux VM for Minikube and
> Azure Cloud Shell or a machine with Azure CLI for AKS. Review Azure
> pricing before creating resources.

------------------------------------------------------------------------

# Part 1 --- Where Can Kubernetes Be Installed?

Kubernetes can be run in several environments. The key distinction is
whether your team manages the Kubernetes control plane and nodes or a
cloud provider manages some of those components.

## 1.1 Deployment environments

  ----------------------------------------------------------------------------------
  Environment       Typical approach  Who manages the control      Common use
                                      plane?                       
  ----------------- ----------------- ---------------------------- -----------------
  Physical servers  Install           Your organization            On-premises
  / bare metal      Kubernetes using                               production,
                    kubeadm or a                                   specialized
                    platform such as                               infrastructure
                    OpenShift                                      

  On-premises       Create Linux VMs  Your organization            Data-center
  virtual machines  and install                                    workloads,
                    Kubernetes using                               private cloud
                    kubeadm or                                     
                    another                                        
                    distribution                                   

  AWS virtual       Create EC2        Your organization            Self-managed
  machines          instances and                                  Kubernetes on AWS
                    install                                        
                    Kubernetes                                     
                    yourself                                       

  Azure virtual     Create Azure VMs  Your organization            Lab, testing, or
  machines          and install                                    self-managed
                    Kubernetes                                     clusters
                    yourself, or use                               
                    Minikube for                                   
                    learning                                       

  Local workstation Minikube, kind,   Local tool manages a local   Learning and
                    or Docker Desktop cluster                      development
                    Kubernetes                                     

  Amazon EKS        Managed           AWS manages the control      Cloud production
                    Kubernetes        plane; customer manages      workloads
                    service on AWS    worker capacity and          
                                      configuration according to   
                                      the chosen mode              

  Azure AKS         Managed           Azure manages the Kubernetes Cloud production
                    Kubernetes        control plane; customer      workloads
                    service on Azure  manages workloads and        
                                      selected                     
                                      node-pool/network/security   
                                      settings                     

  Google GKE        Managed           Google manages the control   Cloud production
                    Kubernetes        plane; worker management     workloads
                    service on Google depends on the operating     
                    Cloud             mode                         
  ----------------------------------------------------------------------------------

## 1.2 Important concepts

-   **Self-managed Kubernetes:** You are responsible for installing,
    upgrading, securing, and operating the control plane and worker
    nodes.
-   **Managed Kubernetes:** The cloud provider operates the Kubernetes
    control plane. You still manage applications, access, resource
    requests, policies, and other responsibilities.
-   **Minikube:** A tool that runs a Kubernetes cluster locally or on a
    VM. It is useful for demonstrations, learning, and development---not
    a replacement for a production-managed service.
-   **AKS:** Azure Kubernetes Service, a managed Kubernetes service.
    Azure operates the control plane; you configure the cluster and run
    your applications.

## 1.3 Basic Kubernetes architecture

A Kubernetes cluster contains:

### Control plane

-   **API server (`kube-apiserver`):** Entry point for Kubernetes API
    requests.
-   **etcd:** Stores Kubernetes cluster state and configuration.
-   **Scheduler (`kube-scheduler`):** Selects a suitable node for newly
    created Pods.
-   **Controller manager (`kube-controller-manager`):** Runs controllers
    that reconcile actual state with desired state.
-   **Cloud controller manager:** Integrates Kubernetes with
    cloud-provider functionality where applicable.

### Worker node

-   **kubelet:** Ensures containers described by Pod specifications are
    running.
-   **Container runtime:** Runs containers, commonly containerd.
-   **kube-proxy or equivalent networking implementation:** Supports
    Service networking; some cluster networking solutions implement this
    functionality differently.
-   **Pods:** The smallest deployable Kubernetes units, containing one
    or more containers.

In managed AKS, Azure manages the control plane. Worker nodes run in the
customer's Azure subscription, except where a different managed compute
mode applies.

------------------------------------------------------------------------

# Part 2 --- Demo A: Install Minikube on an Azure Ubuntu VM

## 2.1 Demo architecture

``` text
Your Laptop
   |
   | SSH
   v
Azure Ubuntu VM
   |
   +-- Docker Engine
   |
   +-- Minikube
         |
         +-- Single-node Kubernetes cluster
               +-- Control-plane components
               +-- Worker workloads
               +-- kubectl
```

For this demo, Minikube uses the **Docker driver**. The VM itself hosts
Docker, and Minikube runs Kubernetes in a Docker container.

## 2.2 Prerequisites

-   An Azure subscription with permission to create a resource group,
    VM, network resources, and public IP.
-   Azure CLI on your laptop, or use Azure Portal.
-   An Ubuntu LTS VM. A practical lab starting point is 2 vCPUs and 4 GB
    RAM; more memory is helpful for additional workloads.
-   SSH access to the VM.
-   Outbound internet access from the VM to download packages and
    images.
-   A user account with `sudo` privileges.

> **Security:** Restrict SSH (TCP 22) to your own public IP address. Do
> not expose the Kubernetes API or Docker daemon publicly. A public IP
> is optional if you use Bastion, VPN, or another private access method.

## 2.3 Step 1 --- Create a resource group

Run on your local machine in a terminal with Azure CLI installed:

``` bash
az login
az account list --output table
az account set --subscription "<SUBSCRIPTION_ID>"

az group create \
  --name rg-k8s-minikube-lab \
  --location centralindia
```

Verify:

``` bash
az group show \
  --name rg-k8s-minikube-lab \
  --output table
```

## 2.4 Step 2 --- Create an Ubuntu VM

Replace `<YOUR_PUBLIC_IP>` with your public IP in CIDR format, for
example `203.0.113.10/32` (use your actual address, not this
documentation example).

``` bash
az vm create \
  --resource-group rg-k8s-minikube-lab \
  --name vm-minikube-lab \
  --image Ubuntu2204 \
  --size Standard_B2s \
  --admin-username azureuser \
  --authentication-type ssh \
  --generate-ssh-keys \
  --public-ip-sku Standard \
  --nsg-rule SSH
```

Restrict the VM's SSH rule to your IP. The exact NSG rule name can vary;
inspect the VM's network security group first:

``` bash
az vm show \
  --resource-group rg-k8s-minikube-lab \
  --name vm-minikube-lab \
  --show-details \
  --query "{publicIp:publicIps,privateIp:privateIps}" \
  --output table

az network nsg list \
  --resource-group rg-k8s-minikube-lab \
  --output table
```

In Azure Portal, open the VM's network interface or associated NSG, edit
the inbound SSH rule, and set **Source** to your IP address (CIDR
`/32`). Alternatively, create a narrowly scoped NSG rule using your
actual NSG and rule names.

Connect:

``` bash
ssh azureuser@<VM_PUBLIC_IP>
```

## 2.5 Step 3 --- Update Ubuntu

Run inside the VM:

``` bash
sudo apt-get update
sudo apt-get upgrade -y
sudo apt-get install -y curl wget apt-transport-https ca-certificates gnupg
```

## 2.6 Step 4 --- Install Docker Engine

Install Docker from Ubuntu's package repository for a simple lab:

``` bash
sudo apt-get install -y docker.io
sudo systemctl enable --now docker
sudo systemctl status docker --no-pager
```

Allow your user to run Docker without `sudo`:

``` bash
sudo usermod -aG docker "$USER"
```

Apply the new group membership by logging out and reconnecting, or run:

``` bash
newgrp docker
```

Verify:

``` bash
docker version
docker run --rm hello-world
```

If Docker commands return a permission error, reconnect to the VM and
verify group membership:

``` bash
groups
```

## 2.7 Step 5 --- Install kubectl

Download the current stable kubectl release:

``` bash
KUBECTL_VERSION="$(curl -L -s https://dl.k8s.io/release/stable.txt)"

curl -LO "https://dl.k8s.io/release/${KUBECTL_VERSION}/bin/linux/amd64/kubectl"
curl -LO "https://dl.k8s.io/release/${KUBECTL_VERSION}/bin/linux/amd64/kubectl.sha256"

echo "$(cat kubectl.sha256)  kubectl" | sha256sum --check

sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
rm -f kubectl kubectl.sha256

kubectl version --client
```

## 2.8 Step 6 --- Install Minikube

Download and install the Linux AMD64 binary:

``` bash
curl -LO https://storage.googleapis.com/minikube/releases/latest/minikube-linux-amd64
sudo install minikube-linux-amd64 /usr/local/bin/minikube
rm -f minikube-linux-amd64

minikube version
```

## 2.9 Step 7 --- Start the Minikube cluster

Use the Docker driver:

``` bash
minikube start --driver=docker
```

If you want to specify resources for the lab:

``` bash
minikube start \
  --driver=docker \
  --cpus=2 \
  --memory=3072
```

Check cluster status:

``` bash
minikube status
kubectl cluster-info
kubectl get nodes -o wide
kubectl get pods -A
```

Expected result: a node appears with `Ready` status. Some system Pods
may take a short time to become ready.

## 2.10 Step 8 --- Understand the cluster

``` bash
kubectl get nodes
kubectl get namespaces
kubectl get pods -n kube-system
kubectl get componentstatuses
```

> `kubectl get componentstatuses` is deprecated/removed in modern
> Kubernetes versions and may not work. Prefer checking Nodes, system
> Pods, and cluster events.

Inspect events:

``` bash
kubectl get events -A --sort-by=.metadata.creationTimestamp
```

## 2.11 Step 9 --- Deploy a sample NGINX application

Create a deployment:

``` bash
kubectl create deployment nginx-demo --image=nginx:stable
```

Scale it to two replicas:

``` bash
kubectl scale deployment nginx-demo --replicas=2
```

Check the deployment and Pods:

``` bash
kubectl get deployments
kubectl get pods -o wide
kubectl rollout status deployment/nginx-demo
```

Expose it as a NodePort Service:

``` bash
kubectl expose deployment nginx-demo \
  --type=NodePort \
  --port=80
```

Inspect the Service:

``` bash
kubectl get svc nginx-demo
minikube service nginx-demo --url
```

The command may print a URL. Because Minikube is running inside a remote
Azure VM, that URL may be reachable only from inside the VM or through
an SSH tunnel. Do not open a broad public firewall rule just for this
demo.

Test from inside the VM:

``` bash
kubectl port-forward service/nginx-demo 8080:80
```

In a second SSH session to the VM:

``` bash
curl http://127.0.0.1:8080
```

Stop port-forwarding with `Ctrl+C`.

## 2.12 Step 10 --- Deploy using a YAML manifest

Create a file:

``` bash
cat <<'EOF' > nginx-deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nginx-yaml
spec:
  replicas: 2
  selector:
    matchLabels:
      app: nginx-yaml
  template:
    metadata:
      labels:
        app: nginx-yaml
    spec:
      containers:
        - name: nginx
          image: nginx:stable
          ports:
            - name: http
              containerPort: 80
          resources:
            requests:
              cpu: 100m
              memory: 64Mi
            limits:
              cpu: 500m
              memory: 128Mi
---
apiVersion: v1
kind: Service
metadata:
  name: nginx-yaml
spec:
  type: ClusterIP
  selector:
    app: nginx-yaml
  ports:
    - name: http
      port: 80
      targetPort: 80
EOF
```

Apply and verify:

``` bash
kubectl apply -f nginx-deployment.yaml
kubectl get deployment, pods
kubectl get svc nginx-yaml
kubectl describe deployment nginx-yaml
```

Test using port-forward:

``` bash
kubectl port-forward service/nginx-yaml 8081:80
```

In another terminal:

``` bash
curl http://127.0.0.1:8081
```

## 2.13 Step 11 --- Useful Minikube commands

``` bash
minikube status
minikube dashboard
minikube stop
minikube start
minikube delete
kubectl config current-context
kubectl config get-contexts
```

`minikube dashboard` may provide a local URL. Use a secure tunnel or
local browser access rather than exposing the dashboard publicly.

## 2.14 Step 12 --- Clean up Minikube demo resources

Delete the sample workloads:

``` bash
kubectl delete -f nginx-deployment.yaml
kubectl delete deployment nginx-demo
kubectl delete service nginx-demo
```

Stop or delete the Minikube cluster:

``` bash
minikube stop
# To remove the cluster completely:
minikube delete
```

When finished with the Azure VM, delete the resource group **only if it
contains no resources you need**:

``` bash
az group delete \
  --name rg-k8s-minikube-lab \
  --yes \
  --no-wait
```

------------------------------------------------------------------------

# Part 3 --- Demo B: Deploy an Azure Kubernetes Service (AKS) Cluster

## 3.1 AKS architecture overview

``` text
Administrator / Developer
        |
        | Azure CLI / kubectl
        v
Azure Resource Manager
        |
        v
AKS Managed Control Plane
(API Server, etcd, Scheduler, Controllers)
        |
        v
Customer Azure Subscription
  +-- Node Resource Group (managed by Azure)
  |     +-- VM Scale Sets / Worker Nodes
  |     +-- Networking and supporting resources
  |
  +-- AKS Cluster Resource
        +-- System node pool
        +-- User node pool (optional)
        +-- Kubernetes workloads
```

Azure manages the control plane. You are responsible for workloads and
for configuring cluster access, node pools, networking, identity,
security, scaling, and operations according to your requirements.

## 3.2 AKS deployment choices to explain

  -----------------------------------------------------------------------
  Decision                Common options          Notes
  ----------------------- ----------------------- -----------------------
  Region                  Azure regions that      Choose a region based
                          support AKS and         on latency,
                          selected features       availability,
                                                  compliance, and cost

  Kubernetes version      A supported version     Check available
                          offered in the selected versions before
                          region                  creation

  Node pool mode          System and User         System pool runs
                                                  critical system Pods;
                                                  user pools are for
                                                  application workloads

  Node size               VM SKU such as a        Match CPU/RAM and
                          general-purpose or      workload needs
                          memory-optimized size   

  Node count              Fixed count or          Autoscaling requires
                          autoscaling             min/max boundaries

  Networking              Azure CNI Overlay,      Choose based on IP
                          Azure CNI, or other     planning, network
                          supported modes         integration, and
                                                  requirements

  API server access       Public endpoint or      Private clusters
                          private cluster         require private network
                                                  connectivity

  Identity                Managed identity /      Prefer managed
                          workload identity       identities over
                          configuration           long-lived credentials

  Authentication          Microsoft Entra ID      Configure
                          integration and         least-privilege access
                          Kubernetes RBAC         

  Ingress                 Application Gateway for Select based on
                          Containers, NGINX or    architecture and
                          other supported ingress support requirements
                          solutions               

  Registry                Azure Container         Grant AKS permission to
                          Registry (ACR) or       pull images
                          another accessible      
                          registry                

  Monitoring              Azure Monitor,          Enable according to
                          Container Insights,     operational needs
                          managed Prometheus and  
                          Grafana options         

  Availability            Availability zones      Zone support varies by
                          where supported; node   region and SKU
                          pool sizing             

  Cost                    VM size, node count,    Review pricing and
                          disks, networking,      remove lab resources
                          monitoring, and other   afterward
                          services                
  -----------------------------------------------------------------------

> AKS features, API flags, networking options, and supported versions
> change over time. Use `az aks create --help` and the official AKS
> documentation to confirm options for your subscription and region.

## 3.3 Prerequisites

-   Azure subscription and permission to create AKS and related
    resources.
-   Azure CLI installed, or use Azure Cloud Shell.
-   `kubectl` installed.
-   A region where the chosen AKS features and VM SKU are available.
-   For a private AKS cluster, a suitable private network path to the
    API server.

Sign in and choose the subscription:

``` bash
az login
az account set --subscription "<SUBSCRIPTION_ID>"
az account show --output table
```

Check the CLI version:

``` bash
az version
az upgrade
```

Check AKS creation options:

``` bash
az aks create --help
az aks get-versions --location centralindia --output table
```

## 3.4 Step 1 --- Create an AKS resource group

``` bash
az group create \
  --name rg-aks-session \
  --location centralindia
```

Verify:

``` bash
az group show \
  --name rg-aks-session \
  --output table
```

## 3.5 Step 2 --- Create a basic AKS cluster (CLI)

This is a simple learning cluster. The example uses a system node pool
with two nodes and enables cluster monitoring metrics where supported by
the current CLI and subscription.

``` bash
az aks create \
  --resource-group rg-aks-session \
  --name aks-session-demo \
  --location centralindia \
  --node-count 2 \
  --node-vm-size Standard_D2s_v5 \
  --generate-ssh-keys \
  --enable-managed-identity
```

Notes: - The selected VM SKU must be available in the region and quota
must be sufficient. - For a lab, a smaller supported VM SKU may reduce
cost, but ensure it meets AKS requirements. - `--generate-ssh-keys`
creates or uses SSH keys for node access; it does not enable public SSH
access to nodes by itself. - For production, explicitly plan networking,
identity, access control, monitoring, availability, and upgrade settings
instead of relying on defaults.

Wait for creation to finish. Then inspect:

``` bash
az aks show \
  --resource-group rg-aks-session \
  --name aks-session-demo \
  --output table
```

## 3.6 Step 3 --- Connect to the AKS cluster

Get credentials:

``` bash
az aks get-credentials \
  --resource-group rg-aks-session \
  --name aks-session-demo
```

Verify the active context and nodes:

``` bash
kubectl config current-context
kubectl get nodes -o wide
kubectl get namespaces
kubectl get pods -A
```

If you have multiple clusters, inspect and switch contexts carefully:

``` bash
kubectl config get-contexts
kubectl config use-context <CONTEXT_NAME>
```

## 3.7 Step 4 --- Deploy a sample application to AKS

Create a deployment:

``` bash
kubectl create deployment nginx-aks --image=nginx:stable
kubectl scale deployment nginx-aks --replicas=2
kubectl rollout status deployment/nginx-aks
kubectl get pods -o wide
```

Expose it using a Kubernetes LoadBalancer Service:

``` bash
kubectl expose deployment nginx-aks \
  --type=LoadBalancer \
  --port=80 \
  --target-port=80
```

Check the external IP:

``` bash
kubectl get service nginx-aks --watch
```

Wait for `EXTERNAL-IP` to be assigned, then open `http://<EXTERNAL-IP>`
in a browser or test:

``` bash
curl http://<EXTERNAL-IP>
```

A public LoadBalancer creates Azure resources and may incur charges. If
you do not need public access, use `ClusterIP` and
`kubectl port-forward` for testing.

## 3.8 Step 5 --- Deploy an application using YAML

Create the manifest:

``` bash
cat <<'EOF' > aks-nginx.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nginx-aks-yaml
spec:
  replicas: 2
  selector:
    matchLabels:
      app: nginx-aks-yaml
  template:
    metadata:
      labels:
        app: nginx-aks-yaml
    spec:
      containers:
        - name: nginx
          image: nginx:stable
          ports:
            - name: http
              containerPort: 80
          resources:
            requests:
              cpu: 100m
              memory: 64Mi
            limits:
              cpu: 500m
              memory: 128Mi
---
apiVersion: v1
kind: Service
metadata:
  name: nginx-aks-yaml
spec:
  type: ClusterIP
  selector:
    app: nginx-aks-yaml
  ports:
    - name: http
      port: 80
      targetPort: 80
EOF
```

Apply and validate:

``` bash
kubectl apply -f aks-nginx.yaml
kubectl get deployment,pods,svc
kubectl describe deployment nginx-aks-yaml
kubectl rollout status deployment/nginx-aks-yaml
```

Test locally through port-forward:

``` bash
kubectl port-forward service/nginx-aks-yaml 8082:80
```

In another terminal:

``` bash
curl http://127.0.0.1:8082
```

## 3.9 Step 6 --- Create a cluster with a dedicated user node pool

A common pattern is to keep system workloads on a system pool and
application workloads on a user pool.

Create a cluster with a system pool:

``` bash
az aks create \
  --resource-group rg-aks-session \
  --name aks-pools-demo \
  --location centralindia \
  --node-count 2 \
  --node-vm-size Standard_D2s_v5 \
  --nodepool-name systempool \
  --nodepool-mode System \
  --enable-managed-identity \
  --generate-ssh-keys
```

Add a user node pool:

``` bash
az aks nodepool add \
  --resource-group rg-aks-session \
  --cluster-name aks-pools-demo \
  --name apppool \
  --mode User \
  --node-count 2 \
  --node-vm-size Standard_D2s_v5
```

Verify:

``` bash
az aks nodepool list \
  --resource-group rg-aks-session \
  --cluster-name aks-pools-demo \
  --output table
```

> Node pool names must follow AKS naming rules. Confirm that the
> selected VM size is supported in the chosen region.

## 3.10 Step 7 --- Enable cluster autoscaling (example)

Autoscaling adjusts the number of nodes in a pool within configured
boundaries. This example enables autoscaling on a user pool:

``` bash
az aks nodepool update \
  --resource-group rg-aks-session \
  --cluster-name aks-pools-demo \
  --name apppool \
  --enable-cluster-autoscaler \
  --min-count 1 \
  --max-count 4
```

Check the pool:

``` bash
az aks nodepool show \
  --resource-group rg-aks-session \
  --cluster-name aks-pools-demo \
  --name apppool \
  --output table
```

Autoscaling does not automatically increase an application's replica
count. Use a Horizontal Pod Autoscaler (HPA) when application-level
scaling is needed.

## 3.11 Step 8 --- Enable Microsoft Entra ID integration and Azure RBAC

For a real environment, plan authentication and authorization before
granting users access. AKS supports Microsoft Entra ID integration and
Azure RBAC for Kubernetes authorization. The exact creation flags depend
on the desired AKS configuration and current CLI version.

Inspect available options:

``` bash
az aks create --help
az aks update --help
```

For an existing cluster, review the relevant options before applying
them:

``` bash
az aks show \
  --resource-group rg-aks-session \
  --name aks-session-demo \
  --query "{aadProfile:aadProfile,azureRBAC:azureRBACEnabled,identity:identity}" \
  --output json
```

Use least privilege. Avoid sharing administrator credentials or granting
cluster-admin access to ordinary users.

## 3.12 Step 9 --- Attach Azure Container Registry (ACR)

If your container image is stored in Azure Container Registry, attach
the registry to AKS so the cluster can pull images:

``` bash
az acr create \
  --resource-group rg-aks-session \
  --name <UNIQUE_ACR_NAME> \
  --sku Basic
```

Attach the registry:

``` bash
az aks update \
  --resource-group rg-aks-session \
  --name aks-session-demo \
  --attach-acr <UNIQUE_ACR_NAME>
```

Verify:

``` bash
az acr show \
  --name <UNIQUE_ACR_NAME> \
  --query loginServer \
  --output tsv
```

The registry name must be globally unique and follow Azure naming rules.
For production, choose an appropriate SKU and configure image security
and access policies.

## 3.13 Step 10 --- Networking options to discuss

### Azure CNI Overlay

-   Pods receive addresses from a pod CIDR that is separate from the
    VNet subnet address space.
-   Helps reduce consumption of VNet IP addresses for Pods.
-   Plan pod CIDR and service CIDR carefully to avoid overlap with
    connected networks.

### Azure CNI (VNet-integrated pod networking)

-   Pod IP addressing is integrated with the VNet according to the
    selected Azure CNI mode.
-   Requires careful subnet/IP capacity planning.

### Kubenet

-   A legacy networking option in AKS; availability and migration
    considerations depend on current platform support. For new
    deployments, evaluate currently recommended Azure CNI modes.

### Public vs. private API server

-   **Public cluster:** API server has a public endpoint, controlled by
    configured access restrictions and authentication.
-   **Private cluster:** API server is reachable through private
    networking; administrators need a valid private connectivity path.

Check available networking flags:

``` bash
az aks create --help
```

Do not copy networking CIDRs blindly. Choose non-overlapping ranges for
VNet, Pod, and Service networks based on your organization's IP plan.

## 3.14 Step 11 --- Monitoring and troubleshooting commands

``` bash
kubectl get nodes
kubectl get pods -A
kubectl get events -A --sort-by=.metadata.creationTimestamp
kubectl describe pod <POD_NAME>
kubectl logs <POD_NAME>
kubectl logs <POD_NAME> --previous
kubectl top nodes
kubectl top pods -A
```

`kubectl top` requires metrics to be available in the cluster.

Inspect AKS details:

``` bash
az aks show \
  --resource-group rg-aks-session \
  --name aks-session-demo \
  --output json
```

Check node pools:

``` bash
az aks nodepool list \
  --resource-group rg-aks-session \
  --cluster-name aks-session-demo \
  --output table
```

## 3.15 Step 12 --- Clean up AKS resources

Delete the sample workload and Service:

``` bash
kubectl delete -f aks-nginx.yaml
kubectl delete deployment nginx-aks
kubectl delete service nginx-aks
```

Delete a demo AKS cluster:

``` bash
az aks delete \
  --resource-group rg-aks-session \
  --name aks-session-demo \
  --yes \
  --no-wait
```

If you created the additional `aks-pools-demo` cluster, delete it
separately:

``` bash
az aks delete \
  --resource-group rg-aks-session \
  --name aks-pools-demo \
  --yes \
  --no-wait
```

After confirming that the resource group contains no resources you need,
remove it:

``` bash
az group delete \
  --name rg-aks-session \
  --yes \
  --no-wait
```

------------------------------------------------------------------------

# Part 4 --- Minikube vs. AKS

  -----------------------------------------------------------------------
  Feature                 Minikube on Azure VM    AKS
  ----------------------- ----------------------- -----------------------
  Purpose                 Learning, local         Managed Kubernetes for
                          development, testing    cloud workloads

  Control plane           Runs as part of the     Managed by Azure
                          Minikube cluster on the 
                          VM                      

  Worker capacity         Usually a single VM for One or more node pools,
                          this demo               depending on
                                                  configuration

  Setup                   Install Docker,         Provision AKS with
                          kubectl, and Minikube   Azure CLI, Portal, or
                                                  IaC

  Scaling                 Limited by VM resources Node pools and
                          and Minikube            supported autoscaling
                          configuration           options

  Availability            Lab-oriented; single VM Availability options
                          is a single point of    depend on region,
                          failure                 configuration, and
                                                  workload design

  Operations              You maintain the VM and Azure manages the
                          lab environment         control plane; you
                                                  manage workloads and
                                                  selected cluster
                                                  configuration

  Cost                    VM, disk, network, and  AKS-related resources,
                          related Azure resources nodes, disks,
                                                  networking, monitoring,
                                                  and applicable service
                                                  charges
  -----------------------------------------------------------------------

------------------------------------------------------------------------

# Part 5 --- Suggested Live Session Flow

Suggested duration: **75--90 minutes**

1.  **Introduction (10 minutes):** Where Kubernetes can run;
    self-managed vs. managed; control plane and worker nodes.
2.  **Minikube on Azure VM (25--30 minutes):** Create VM, install
    Docker, kubectl, and Minikube; start cluster; verify nodes and Pods.
3.  **Minikube workload demo (10 minutes):** Deploy NGINX, scale
    replicas, expose a Service, test with port-forward.
4.  **AKS deployment (20--25 minutes):** Create resource group and AKS,
    get credentials, inspect nodes, deploy NGINX, expose it.
5.  **AKS options (10 minutes):** Node pools, autoscaling, networking,
    identity, ACR, monitoring, and cost.
6.  **Q&A and cleanup (5 minutes):** Compare Minikube and AKS; remove
    demo resources.

------------------------------------------------------------------------

# Part 6 --- Quick Demo Checklist

## Before the session

-   [ ] Azure subscription and permissions are available.
-   [ ] Region and VM SKU are confirmed.
-   [ ] SSH access is restricted to your IP or private access method.
-   [ ] Azure CLI and `kubectl` are available.
-   [ ] Budget and cleanup plan are ready.

## Minikube demo

-   [ ] Create and connect to Ubuntu VM.
-   [ ] Install Docker Engine.
-   [ ] Install `kubectl` and Minikube.
-   [ ] Run `minikube start --driver=docker`.
-   [ ] Verify with `kubectl get nodes` and `kubectl get pods -A`.
-   [ ] Deploy NGINX and test it with port-forward.

## AKS demo

-   [ ] Create resource group.
-   [ ] Create AKS cluster.
-   [ ] Run `az aks get-credentials`.
-   [ ] Verify nodes and system Pods.
-   [ ] Deploy NGINX and test access.
-   [ ] Explain node pools, autoscaling, networking, identity, and ACR.
-   [ ] Delete test resources when finished.

------------------------------------------------------------------------

# Part 7 --- Interview / Audience Questions

**Q1. Where can Kubernetes be installed?**\
On physical servers, on-premises VMs, cloud VMs such as AWS EC2 or Azure
VMs, and through managed services such as EKS, AKS, and GKE. Tools such
as Minikube and kind are commonly used for learning and development.

**Q2. What is the difference between Minikube and AKS?**\
Minikube runs a Kubernetes cluster for learning and development. AKS is
a managed Kubernetes service in which Azure operates the control plane.

**Q3. Who manages the Kubernetes control plane in AKS?**\
Azure manages the AKS control plane. Customers manage their applications
and configure cluster resources and access according to their needs.

**Q4. What is a node pool in AKS?**\
A node pool is a group of nodes with a shared configuration, such as VM
size and scaling settings. AKS supports system and user node pools.

**Q5. What is the purpose of `az aks get-credentials`?**\
It retrieves cluster access credentials and updates the local kubeconfig
so `kubectl` can communicate with the AKS cluster.

**Q6. Why might a Service of type `LoadBalancer` take time to get an
external IP?**\
Kubernetes requests a cloud load balancer, and the cloud provider must
provision and configure the required resources. The IP may remain
pending if provisioning fails or required permissions or quota are
missing.

**Q7. Does node autoscaling scale application Pods?**\
No. Cluster autoscaling changes node capacity. A Horizontal Pod
Autoscaler can change the number of Pod replicas based on configured
metrics.

**Q8. Should Minikube be used as a production AKS replacement?**\
No. Minikube is primarily designed for learning, development, and
testing. Production architecture requires availability, security,
scaling, operational controls, and support appropriate to the workload.

------------------------------------------------------------------------

## Official documentation

-   Minikube: https://minikube.sigs.k8s.io/docs/
-   Kubernetes documentation: https://kubernetes.io/docs/
-   Install kubectl: https://kubernetes.io/docs/tasks/tools/
-   Azure Kubernetes Service (AKS):
    https://learn.microsoft.com/azure/aks/
-   Create an AKS cluster using Azure CLI:
    https://learn.microsoft.com/azure/aks/learn/quick-kubernetes-deploy-cli
-   AKS node pools:
    https://learn.microsoft.com/azure/aks/create-node-pools
-   Azure CLI reference: https://learn.microsoft.com/cli/azure/aks
