#!/usr/bin/env bash

set -euo pipefail

# -------------------------------
#  PART 1: Prerequisite Checks
# -------------------------------

say() { echo -e "\n==> $*"; }

say "Checking prerequisites..."

# Check Docker
if ! command -v docker >/dev/null 2>&1; then
  echo "Docker not installed. Please install Docker Desktop first."
  exit 1
fi

# Check Docker Compose
if docker compose version >/dev/null 2>&1; then
  COMPOSE="docker compose"
elif command -v docker-compose >/dev/null 2>&1; then
  COMPOSE="docker-compose"
else
  echo "Docker Compose not installed."
  exit 1
fi

# Check Docker running
if ! docker info >/dev/null 2>&1; then
  echo "Docker daemon not running. Please start Docker Desktop."
  exit 1
fi

# Check required ports
for PORT in 80 3000 5000; do
  if lsof -i :$PORT >/dev/null 2>&1; then
    echo "Port $PORT is in use."
  else
    echo "Port $PORT available."
  fi
done

# -------------------------------
#  PART 2: Navigate to Project Folder
# -------------------------------

say "Navigating to project directory..."

PROJECT_DIR="D:\DevOps\Module6_Part1_david_yazon\Module6_part1_david_yazon"

if [ ! -d "$PROJECT_DIR" ]; then
  echo "Project directory not found: $PROJECT_DIR"
  exit 1
fi

cd "$PROJECT_DIR"
say "Now inside: $(pwd)"

# Validate docker-compose.yml exists
if [ ! -f "docker-compose.yml" ]; then
  echo "docker-compose.yml is missing! Script cannot continue."
  exit 1
else
  echo "docker-compose.yml found."
fi

# -------------------------------
#  PART 3: Build and Deploy
# -------------------------------

say "Cleaning old containers (idempotent step)..."
$COMPOSE down -v || true

say "Building and deploying containers..."
$COMPOSE up --build -d

say "Listing images..."
docker images

say "Listing running containers..."
docker ps

# -------------------------------
#  PART 4: Health Checks
# -------------------------------

say "Performing health checks..."

# Check frontend through nginx
if curl -I http://localhost 2>/dev/null | grep -q "200"; then
  say "Frontend reachable at http://localhost"
else
  echo "Frontend check FAILED"
  exit 1
fi

# Check backend via API route
if curl -I http://localhost/api/login 2>/dev/null | grep -q "200"; then
  say "Backend reachable at /api/login"
else
  echo "Backend check FAILED"
  exit 1
fi

# -------------------------------
#  PART 5: Verify & Inspect Nginx
# -------------------------------

say "Collecting Nginx container ID..."
NGINX_CONTAINER=$($COMPOSE ps -q nginx || true)

if [ -z "$NGINX_CONTAINER" ]; then
  echo "Nginx container not found. Check docker-compose.yml service name."
  exit 1
fi

say "Nginx container found: $NGINX_CONTAINER"

# ---------- NEW JQ-SAFE BLOCK ----------
say "Checking if jq is installed..."
if ! command -v jq >/dev/null 2>&1; then
  say "jq not found — Git Bash cannot auto-install jq. Skipping jq extraction steps."
  JQ_AVAILABLE=false
else
  say "jq is installed."
  JQ_AVAILABLE=true
fi
# ---------------------------------------

# Inspect nginx image
say "Inspecting nginx:alpine image..."
docker inspect nginx:alpine > nginx-logs.json

say "nginx-logs.json file created."

# ---------- CONDITIONAL EXTRACTION ----------
if [ "$JQ_AVAILABLE" = true ]; then
  say "Extracting RepoTags..."
  jq '.[0].RepoTags' nginx-logs.json

  say "Extracting Created timestamp..."
  jq '.[0].Created' nginx-logs.json

  say "Extracting OS..."
  jq '.[0].Os' nginx-logs.json

  say "Extracting Config..."
  jq '.[0].Config' nginx-logs.json

  say "Extracting ExposedPorts..."
  jq '.[0].Config.ExposedPorts' nginx-logs.json
else
  say "jq not installed — skipping field extraction. Use nginx-logs.json manually if needed."
fi
# ---------------------------------------------

# -------------------------------
#  PART 6: Functional Validation
# -------------------------------

say "Starting functional validation steps..."

echo "
=====================================================
 MANUAL FUNCTIONAL VALIDATION REQUIRED
=====================================================
Please perform the following steps in your browser:

 1. Go to: http://localhost
 2. Click Register
 3. Create a new user account
 4. Log in using the new credentials
 5. Make a deposit (example: 600.45)
 6. Make a withdrawal (example: 100.00)
 7. Confirm that the Dashboard balance updates correctly

=====================================================
"

say "Checking backend API endpoints for expected responses..."

if curl -s -o /dev/null -w "%{http_code}" http://localhost/api/login | grep -q "200"; then
    say "Login page endpoint is reachable."
else
    echo "Login endpoint FAILED."
fi

if curl -s -o /dev/null -w "%{http_code}" http://localhost/api/register | grep -q "200"; then
    say "Register page endpoint is reachable."
else
    echo "Register endpoint FAILED."
fi

say "Functional validation steps completed."

# -------------------------------
#  PART 7: Cleanup
# -------------------------------

say "Cleanup section (optional but recommended)..."

echo "
=====================================================
 CLEANUP OPTIONS
=====================================================
Choose one of the following cleanup behaviors:

 1. Stop all containers (safe, default)
 2. Stop and remove containers + volumes
 3. Full cleanup (containers, images, cache)
 4. Skip cleanup

=====================================================
"

read -p "Enter choice (1/2/3/4): " CLEANUP_CHOICE

case "$CLEANUP_CHOICE" in

  1)
    say "Stopping containers only..."
    $COMPOSE stop || true
    ;;

  2)
    say "Stopping and removing containers and volumes..."
    $COMPOSE down -v || true
    ;;

  3)
    say "Performing full cleanup (containers, images, cache)..."
    $COMPOSE down -v || true
    docker system prune -a -f || true
    ;;

  4)
    say "Skipping cleanup. Environment remains running."
    ;;

  *)
    echo "Invalid choice. Skipping cleanup."
    ;;
esac

say "Script completed successfully!"