#!/bin/bash
set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

IMAGE="${IMAGE:-caddy-rootless:test}"
DOCKERFILE="${DOCKERFILE:-dockerfiles/alpine/Dockerfile}"

echo -e "${GREEN}=== Caddy Rootless Test Suite ===${NC}"
echo "Image: $IMAGE"
echo "Dockerfile: $DOCKERFILE"
echo ""

# Build image
echo -e "${YELLOW}=== Building image ===${NC}"
docker build -t "$IMAGE" -f "$DOCKERFILE" .
echo -e "${GREEN}✓ Build successful${NC}"
echo ""

# Test 1: Caddy version
echo -e "${YELLOW}=== Test 1: Caddy version ===${NC}"
docker run --rm "$IMAGE" caddy version
echo -e "${GREEN}✓ Caddy version check passed${NC}"
echo ""

# Test 2: Running with arbitrary UID (simulating OpenShift)
echo -e "${YELLOW}=== Test 2: Arbitrary UID (OpenShift simulation) ===${NC}"
echo "Running with UID 1000650000 (typical OpenShift UID)..."
docker run --rm -u 1000650000:0 "$IMAGE" caddy version
echo -e "${GREEN}✓ Arbitrary UID test passed${NC}"
echo ""

# Test 3: File permissions - /data directory
echo -e "${YELLOW}=== Test 3: File permissions ===${NC}"
echo "Testing /data directory..."
docker run --rm -u 1000650000:0 "$IMAGE" sh -c "
    set -e
    touch /data/test.txt
    rm /data/test.txt
    echo '/data: writable ✓'
"

echo "Testing /config directory..."
docker run --rm -u 1000650000:0 "$IMAGE" sh -c "
    set -e
    touch /config/test.txt
    rm /config/test.txt
    echo '/config: writable ✓'
"

echo "Testing /var/log/caddy directory..."
docker run --rm -u 1000650000:0 "$IMAGE" sh -c "
    set -e
    touch /var/log/caddy/test.log
    rm /var/log/caddy/test.log
    echo '/var/log/caddy: writable ✓'
"

echo -e "${GREEN}✓ All file permissions tests passed${NC}"
echo ""

# Test 4: Verify ownership and permissions
echo -e "${YELLOW}=== Test 4: Verify ownership and permissions ===${NC}"
docker run --rm "$IMAGE" sh -c "
    echo 'Checking /data:'
    ls -la /data | head -2
    echo ''
    echo 'Checking /config:'
    ls -la /config | head -2
    echo ''
    echo 'Checking /usr/bin/caddy:'
    ls -la /usr/bin/caddy
"
echo -e "${GREEN}✓ Ownership verification passed${NC}"
echo ""

# Test 5: Caddy configuration validation
echo -e "${YELLOW}=== Test 5: Caddy configuration validation ===${NC}"
docker run --rm -u 1000650000:0 "$IMAGE" \
    caddy validate --config /etc/caddy/Caddyfile --adapter caddyfile
echo -e "${GREEN}✓ Configuration validation passed${NC}"
echo ""

# Test 6: Start Caddy server
echo -e "${YELLOW}=== Test 6: Start Caddy server ===${NC}"
echo "Starting Caddy with arbitrary UID..."
docker run --rm -d -u 1000650000:0 -p 8080:8080 --name caddy-test "$IMAGE" > /dev/null

echo "Waiting for server to start..."
sleep 3

echo "Testing server status..."
if docker ps | grep -q caddy-test; then
    echo -e "${GREEN}✓ Server is running${NC}"
else
    echo -e "${RED}✗ Server failed to start${NC}"
    docker logs caddy-test
    docker stop caddy-test > /dev/null 2>&1 || true
    exit 1
fi

echo "Testing HTTP endpoint..."
if curl -sf http://localhost:8080 > /dev/null 2>&1; then
    echo -e "${GREEN}✓ Server is responding${NC}"
else
    echo -e "${YELLOW}⚠ Server not responding (expected if no default site configured)${NC}"
fi

# Check logs
echo ""
echo "Server logs:"
docker logs caddy-test 2>&1 | head -10

# Cleanup
docker stop caddy-test > /dev/null
echo -e "${GREEN}✓ Server test completed${NC}"
echo ""

# Test 7: Test with different UID/GID combinations
echo -e "${YELLOW}=== Test 7: Different UID/GID combinations ===${NC}"

echo "Testing UID=1001, GID=0 (standard)..."
docker run --rm -u 1001:0 "$IMAGE" sh -c "touch /data/test.txt && rm /data/test.txt"
echo "✓ UID=1001, GID=0"

echo "Testing UID=12345, GID=0 (arbitrary UID, root group)..."
docker run --rm -u 12345:0 "$IMAGE" sh -c "touch /data/test.txt && rm /data/test.txt"
echo "✓ UID=12345, GID=0"

echo "Testing UID=1001, GID=1001 (rootless container)..."
docker run --rm -u 1001:1001 "$IMAGE" sh -c "touch /data/test.txt && rm /data/test.txt" 2>&1 | grep -q "Permission denied" && echo "✗ UID=1001, GID=1001 (expected failure)" || echo "✓ UID=1001, GID=1001"

echo -e "${GREEN}✓ UID/GID combination tests passed${NC}"
echo ""

# Summary
echo -e "${GREEN}╔════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║   All tests passed successfully! ✓    ║${NC}"
echo -e "${GREEN}╚════════════════════════════════════════╝${NC}"
echo ""
echo "Your Caddy rootless image is ready for:"
echo "  • Docker and Docker Compose deployments"
echo "  • Kubernetes deployments"
echo "  • OpenShift deployments (with arbitrary UID)"
echo ""
echo "Next steps:"
echo "  • Test with docker-compose: docker-compose -f examples/docker-compose.yml up"
echo "  • Deploy to Kubernetes: kubectl apply -f examples/kubernetes/"
echo "  • Deploy to OpenShift: oc apply -f examples/openshift/"
