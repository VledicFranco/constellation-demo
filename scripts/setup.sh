#!/usr/bin/env bash
set -euo pipefail

# One-time setup script for the Constellation Demo
# Builds the TS SDK tarball and prepares the Docker build context

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
ENGINE_DIR="$(dirname "$PROJECT_DIR")/constellation-engine"

echo "=== Constellation Demo Setup ==="
echo ""

# Step 1: Build TS SDK tarball for Docker
echo "[1/3] Building TypeScript SDK tarball..."
if [ -d "$ENGINE_DIR/sdks/typescript" ]; then
  cd "$ENGINE_DIR/sdks/typescript"
  npm pack
  TARBALL=$(ls -t constellation-engine-provider-sdk-*.tgz | head -1)
  cp "$TARBALL" "$PROJECT_DIR/provider-ts/"
  echo "  Copied $TARBALL to provider-ts/"
else
  echo "  WARNING: constellation-engine/sdks/typescript not found."
  echo "  Docker build for provider-ts will fail without the SDK tarball."
fi

# Step 2: Install TS provider dependencies (local dev)
echo "[2/3] Installing provider-ts dependencies..."
cd "$PROJECT_DIR/provider-ts"
if [ -f "package.json" ]; then
  npm install
  echo "  Dependencies installed."
fi

# Step 3: Verify Docker
echo "[3/3] Checking Docker..."
if command -v docker &> /dev/null; then
  docker --version
  echo "  Docker is available."
else
  echo "  WARNING: Docker not found. Install Docker to run the demo."
fi

echo ""
echo "=== Setup complete ==="
echo ""
echo "To start the demo:"
echo "  docker compose up --build"
echo ""
echo "Or for local development:"
echo "  cd provider-ts && npm run dev"
