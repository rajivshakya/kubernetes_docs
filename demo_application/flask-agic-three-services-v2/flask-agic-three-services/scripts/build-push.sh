#!/usr/bin/env bash
set -euo pipefail

ACR_NAME="${1:?Usage: ./scripts/build-push.sh <acr-name>}"
LOGIN_SERVER="$(az acr show --name "$ACR_NAME" --query loginServer -o tsv)"
az acr login --name "$ACR_NAME"

for SERVICE in user order payment; do
  IMAGE="${LOGIN_SERVER}/${SERVICE}-service:v1"
  docker build -t "$IMAGE" \
    --build-arg "SERVICE_NAME=${SERVICE}" \
    --build-arg "ROUTE_PATH=/${SERVICE}" .
  docker push "$IMAGE"
done

echo "All three images pushed to ${LOGIN_SERVER}"
