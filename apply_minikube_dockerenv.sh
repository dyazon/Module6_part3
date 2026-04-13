#!/usr/bin/env bash

set -euo pipefail

echo "====================================================="
echo "  APPLYING K8s DEPLOYMENT INTO MINIKUBE DOCKER ENV"
echo "====================================================="

say() { echo -e "\n>> $*"; }

# STEP 1: Check prerequisites
say "Checking prerequisites (minikube, kubectl, docker)..."

if ! command -v minikube >/dev/null 2>&1; then
  echo "minikube not found. Please install minikube first."
  exit 1
fi

if ! command -v kubectl >/dev/null 2>&1; then
  echo "kubectl not found. Please install kubectl first."
  exit 1
fi

if ! command -v docker >/dev/null 2>&1; then
  echo "docker not found. Please install Docker Desktop first."
  exit 1
fi

if [ ! -d "k8s" ]; then
  echo "k8s folder not found."
  exit 1
fi

# STEP 2: Ensure Minikube is running
say "Checking Minikube status..."

if ! minikube status --profile minikube >/dev/null 2>&1; then
  say "Minikube not running — starting with Docker driver..."
  minikube start --driver=docker
else
  say "Minikube is already running."
fi

# STEP 3: Point Docker to Minikube Docker daemon
say "Setting Docker CLI to use Minikube Docker daemon..."
eval "$(minikube -p minikube docker-env)"

docker info >/dev/null 2>&1 || {
  echo "Docker inside Minikube is not available."
  exit 1
}

say "Docker is now pointing at Minikube Docker."

# STEP 4: Build images into Minikube
say "Building backend image..."
docker build -t backend:latest ./backend

say "Building transactions image..."
docker build -t transactions:latest ./transactions

say "Building studentportfolio image..."
docker build -t studentportfolio:latest ./studentportfolio

say "Image build complete."

# STEP 5: Verify images inside Minikube node
say "Verifying images inside Minikube Docker daemon..."

docker images | grep -E 'backend|transactions|studentportfolio' || {
  echo "Expected images not found in Minikube Docker."
  exit 1
}

# STEP 6: Apply Kubernetes manifests
say "Applying Kubernetes manifests..."

echo "=== Applying Secrets ==="
kubectl apply -f k8s/backend-secret.yaml

echo "=== Applying ConfigMaps ==="
kubectl apply -f k8s/nginx-configmap.yaml

echo "=== Applying StatefulSets ==="
kubectl apply -f k8s/mongo-statefulset.yaml

echo "=== Applying Deployments ==="
kubectl apply -f k8s/backend-deployment.yaml
kubectl apply -f k8s/transactions-deployment.yaml
kubectl apply -f k8s/studentportfolio-deployment.yaml
kubectl apply -f k8s/nginx-deployment.yaml

echo "=== Applying Services ==="
kubectl apply -f k8s/mongo-service.yaml
kubectl apply -f k8s/backend-service.yaml
kubectl apply -f k8s/nginx-service.yaml
kubectl apply -f k8s/transactions-service.yaml
kubectl apply -f k8s/studentportfolio-service.yaml

echo "=== Applying Horizontal Pod Autoscalers ==="
kubectl apply -f k8s/backend-hpa.yaml
kubectl apply -f k8s/transactions-hpa.yaml

say "All manifests applied."

# STEP 7: Restart deployments
say "Restarting deployments..."
kubectl rollout restart deployment backend
kubectl rollout restart deployment transactions
kubectl rollout restart deployment studentportfolio
kubectl rollout restart deployment nginx

# STEP 8: Wait for pods
say "Waiting for pods to become Ready..."
kubectl wait --for=condition=ready pod -l app=backend --timeout=180s
kubectl wait --for=condition=ready pod -l app=transactions --timeout=180s
kubectl wait --for=condition=ready pod -l app=studentportfolio --timeout=180s
kubectl wait --for=condition=ready pod -l app=nginx --timeout=180s
kubectl wait --for=condition=ready pod -l app=mongo --timeout=180s

# STEP 9: Show pods and services
say "Current pods:"
kubectl get pods

say "Current services:"
kubectl get svc

# STEP 10: Launch app
say "Launching nginx service..."
minikube service nginx

echo
echo "====================================================="
echo "Deployment complete."
echo "====================================================="