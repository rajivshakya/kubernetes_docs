param(
  [Parameter(Mandatory=$true)]
  [string]$AcrName
)

$ErrorActionPreference = "Stop"
$LoginServer = az acr show --name $AcrName --query loginServer -o tsv
if (-not $LoginServer) { throw "Could not find ACR login server. Check the ACR name and Azure login." }

az acr login --name $AcrName
if ($LASTEXITCODE -ne 0) { throw "ACR login failed." }

$services = @(
  @{ Name = "user"; Route = "/user" },
  @{ Name = "order"; Route = "/order" },
  @{ Name = "payment"; Route = "/payment" }
)

foreach ($service in $services) {
  $image = "$LoginServer/$($service.Name)-service:v1"
  docker build -t $image `
    --build-arg "SERVICE_NAME=$($service.Name)" `
    --build-arg "ROUTE_PATH=$($service.Route)" .
  if ($LASTEXITCODE -ne 0) { throw "Docker build failed for $($service.Name)." }

  docker push $image
  if ($LASTEXITCODE -ne 0) { throw "Docker push failed for $($service.Name)." }
}

Write-Host "All three images pushed to $LoginServer"
