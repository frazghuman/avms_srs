#!/bin/bash
# build-offline-package-mac.sh

#=============================================
# AVMS Offline Package Builder for Mac
# Uses Docker Ubuntu container to build package
#=============================================

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}╔═══════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║  AVMS Offline Package Builder (Mac)      ║${NC}"
echo -e "${BLUE}╚═══════════════════════════════════════════╝${NC}"
echo ""

# Check if Docker is installed
if ! command -v docker &> /dev/null; then
    echo -e "${RED}Docker is not installed!${NC}"
    echo "Please install Docker Desktop for Mac first."
    exit 1
fi

# Create working directory
WORK_DIR="$HOME/avms-offline-install"
mkdir -p "$WORK_DIR"

# Create builder script that will run inside Ubuntu container
cat > "$WORK_DIR/build-inside-container.sh" << 'BUILDER_SCRIPT'
#!/bin/bash
set -e

# Update and install required tools
apt-get update
apt-get install -y \
    curl \
    wget \
    genisoimage \
    ca-certificates

# Create directory structure
cd /build
mkdir -p docker-debs docker-images avms-source scripts test-data/sample-files

# Download Docker .deb packages
echo "Downloading Docker packages..."
cd docker-debs

# Download packages without installing
apt-get update
apt-get download \
    docker-ce \
    docker-ce-cli \
    containerd.io \
    docker-buildx-plugin \
    docker-compose-plugin \
    ca-certificates \
    curl \
    gnupg \
    lsb-release \
    iptables \
    pigz

cd ..

echo "Docker packages downloaded: $(ls -1 docker-debs/*.deb | wc -l) files"

# Note: Docker images will be pulled from the Mac host
BUILDER_SCRIPT

chmod +x "$WORK_DIR/build-inside-container.sh"

#---------------------------------------------
# Pull Docker images on Mac host
#---------------------------------------------
echo -e "${YELLOW}Pulling Docker images on Mac...${NC}"
cd "$WORK_DIR"
mkdir -p docker-images

IMAGES=(
    "mongo:7.0"
    "node:18-alpine"
    "python:3.12-slim"
    "nginx:alpine"
    "caddy:2-alpine"
)

for IMAGE in "${IMAGES[@]}"; do
    echo "Pulling $IMAGE..."
    docker pull "$IMAGE"
    
    # Save and compress
    IMAGE_FILE=$(echo "$IMAGE" | tr ':/' '-')
    echo "Saving $IMAGE..."
    docker save "$IMAGE" | gzip > "docker-images/${IMAGE_FILE}.tar.gz"
done

#---------------------------------------------
# Create application source files
#---------------------------------------------
echo -e "${YELLOW}Creating application files...${NC}"
mkdir -p avms-source

# Create docker-compose.yml
cat > avms-source/docker-compose.yml << 'COMPOSE_EOF'
version: '3.8'

services:
  mongodb:
    image: mongo:7.0
    container_name: avms-mongodb
    restart: unless-stopped
    environment:
      MONGO_INITDB_ROOT_USERNAME: admin
      MONGO_INITDB_ROOT_PASSWORD: avms_admin_pass_2024
      MONGO_INITDB_DATABASE: avms
    volumes:
      - mongo-data:/data/db
    ports:
      - "27017:27017"
    networks:
      - avms-network

  backend:
    image: node:18-alpine
    container_name: avms-backend
    restart: unless-stopped
    working_dir: /app
    volumes:
      - ./backend:/app
    ports:
      - "3000:3000"
    depends_on:
      - mongodb
    networks:
      - avms-network
    command: sh -c "npm install && npm start"

  frontend:
    image: nginx:alpine
    container_name: avms-frontend
    restart: unless-stopped
    volumes:
      - ./frontend/dist:/usr/share/nginx/html:ro
    ports:
      - "4201:80"
    networks:
      - avms-network

  fastapi:
    image: python:3.12-slim
    container_name: avms-fastapi
    restart: unless-stopped
    working_dir: /app
    volumes:
      - ./fastapi:/app
    ports:
      - "8000:8000"
    depends_on:
      - mongodb
    networks:
      - avms-network
    command: sh -c "pip install -r requirements.txt && uvicorn main:app --host 0.0.0.0 --port 8000"

  caddy:
    image: caddy:2-alpine
    container_name: avms-proxy
    restart: unless-stopped
    ports:
      - "8088:8088"
    volumes:
      - ./Caddyfile:/etc/caddy/Caddyfile:ro
    networks:
      - avms-network

volumes:
  mongo-data:

networks:
  avms-network:
    driver: bridge
COMPOSE_EOF

#---------------------------------------------
# Create all scripts
#---------------------------------------------
echo -e "${YELLOW}Creating installation scripts...${NC}"
mkdir -p scripts

# Create minimal versions of scripts
cat > scripts/install.sh << 'INSTALL_EOF'
#!/bin/bash
# [Full installation script here - same as Linux version]
echo "Installing AVMS..."
INSTALL_EOF

cat > scripts/check-prerequisites.sh << 'PREREQ_EOF'
#!/bin/bash
# [Full prerequisites script here - same as Linux version]
echo "Checking prerequisites..."
PREREQ_EOF

chmod +x scripts/*.sh

#---------------------------------------------
# Run Ubuntu container to download .deb packages
#---------------------------------------------
echo -e "${YELLOW}Starting Ubuntu container to download .deb packages...${NC}"

docker run --rm \
    -v "$WORK_DIR:/build" \
    ubuntu:22.04 \
    bash /build/build-inside-container.sh

#---------------------------------------------
# Create ISO on Mac
#---------------------------------------------
echo -e "${YELLOW}Creating ISO image...${NC}"

# Create README
cat > "$WORK_DIR/README.txt" << 'README_EOF'
AVMS OFFLINE INSTALLATION PACKAGE
==================================
Built on Mac for Ubuntu deployment

Installation:
1. Copy to Ubuntu server
2. Run: bash scripts/install.sh

README_EOF

# Mac uses hdiutil instead of genisoimage
cd "$WORK_DIR"

# Create ISO using hdiutil (Mac native tool)
ISO_NAME="avms-offline-installer-$(date +%Y%m%d).iso"

# Method 1: Using hdiutil makehybrid (recommended)
echo "Creating ISO with hdiutil..."
hdiutil makehybrid -o "$HOME/$ISO_NAME" \
    -iso \
    -joliet \
    -default-volume-name "AVMS_INSTALLER" \
    "$WORK_DIR"

# Alternative Method 2: Create DMG then convert to ISO
# hdiutil create -volname "AVMS_INSTALLER" -srcfolder "$WORK_DIR" -ov -format UDRO "$HOME/avms-temp.dmg"
# hdiutil convert "$HOME/avms-temp.dmg" -format UDTO -o "$HOME/$ISO_NAME"
# mv "$HOME/${ISO_NAME}.cdr" "$HOME/${ISO_NAME}.iso"
# rm "$HOME/avms-temp.dmg"

if [ -f "$HOME/${ISO_NAME}" ] || [ -f "$HOME/${ISO_NAME}.iso" ]; then
    echo ""
    echo -e "${GREEN}╔═══════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║     ISO CREATION SUCCESSFUL!              ║${NC}"
    echo -e "${GREEN}╚═══════════════════════════════════════════╝${NC}"
    echo ""
    echo "  ISO File: $HOME/${ISO_NAME}"
    echo "  Size: $(ls -lh $HOME/${ISO_NAME}* | awk '{print $5}')"
    echo ""
    echo "  To burn DVD on Mac:"
    echo "  1. Insert blank DVD"
    echo "  2. Open Finder → Applications → Utilities → Disk Utility"
    echo "  3. File → Burn Disk Image → Select the ISO"
    echo ""
else
    echo -e "${RED}ISO creation failed!${NC}"
fi