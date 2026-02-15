#!/bin/bash
# verify-completeness.sh

echo "Checking package completeness..."

MISSING=0
BASE_DIR="$HOME/avms-offline-install"

# Required files checklist
declare -A REQUIRED_FILES=(
    ["docker-debs/docker-ce.deb"]="Docker CE package"
    ["docker-debs/docker-ce-cli.deb"]="Docker CLI package"
    ["docker-debs/containerd.io.deb"]="Containerd package"
    ["docker-debs/docker-compose-plugin.deb"]="Docker Compose plugin"
    ["docker-images/mongo-7.0.tar.gz"]="MongoDB image"
    ["docker-images/node-18-alpine.tar.gz"]="Node.js image"
    ["docker-images/python-3.12-slim.tar.gz"]="Python image"
    ["docker-images/nginx-alpine.tar.gz"]="Nginx image"
    ["docker-images/caddy-2-alpine.tar.gz"]="Caddy image"
    ["avms-source/docker-compose.yml"]="Docker Compose config"
    ["avms-source/Caddyfile"]="Caddy configuration"
    ["scripts/check-prerequisites.sh"]="Prerequisites checker"
    ["scripts/install.sh"]="Main installer"
    ["scripts/load-test-data.sh"]="Test data loader"
    ["scripts/verify-installation.sh"]="Installation verifier"
    ["test-data/init-mongo.js"]="MongoDB init script"
    ["test-data/seed-data.json"]="Seed data"
    ["README.txt"]="Main documentation"
    ["CHECKSUMS.md5"]="Package checksums"
)

echo ""
echo "Verifying required files..."
echo "============================"

for FILE in "${!REQUIRED_FILES[@]}"; do
    FULL_PATH="$BASE_DIR/$FILE"
    if [ -f "$FULL_PATH" ] || [ -f "${FULL_PATH%.deb}"* ] || [ -f "${FULL_PATH%.tar.gz}"* ]; then
        echo "✓ ${REQUIRED_FILES[$FILE]}"
    else
        echo "✗ MISSING: ${REQUIRED_FILES[$FILE]} ($FILE)"
        ((MISSING++))
    fi
done

echo ""
if [ $MISSING -eq 0 ]; then
    echo "✓ ALL FILES PRESENT - Package is complete!"
else
    echo "✗ $MISSING files missing - Package incomplete!"
    exit 1
fi