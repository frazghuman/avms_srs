#!/bin/bash

#=============================================
# AVMS Complete Offline Package Builder
# Downloads ALL requirements and creates ISO
#=============================================

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Base directory
WORK_DIR="$HOME/avms-offline-install"
LOG_FILE="$WORK_DIR/download-log-$(date +%Y%m%d-%H%M%S).txt"

#---------------------------------------------
# Initialize
#---------------------------------------------
echo -e "${BLUE}╔═══════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║  AVMS Offline Package Builder            ║${NC}"
echo -e "${BLUE}╚═══════════════════════════════════════════╝${NC}"
echo ""

# Create directory structure
echo "Creating directory structure..."
mkdir -p "$WORK_DIR"/{docker-debs,docker-images,avms-source,scripts,test-data/sample-files}
cd "$WORK_DIR"

# Start logging
exec > >(tee -a "$LOG_FILE")
exec 2>&1

#---------------------------------------------
# STEP 1: Download Docker Debian Packages
#---------------------------------------------
echo ""
echo -e "${YELLOW}[1/7] Downloading Docker .deb packages...${NC}"
cd "$WORK_DIR/docker-debs"

# Update package lists
sudo apt-get update

# Download Docker and ALL dependencies
apt-get download \
    docker-ce \
    docker-ce-cli \
    containerd.io \
    docker-buildx-plugin \
    docker-compose-plugin \
    docker-ce-rootless-extras

# Download dependencies that might be needed
apt-get download \
    ca-certificates \
    curl \
    gnupg \
    lsb-release \
    iptables \
    libip6tc2 \
    libip4tc2 \
    libnfnetlink0 \
    libnetfilter-conntrack3 \
    pigz \
    xz-utils

# Download additional runtime dependencies
apt-get download \
    libseccomp2 \
    libapparmor1 \
    libltdl7 \
    libdevmapper1.02.1 \
    dbus-user-session \
    uidmap \
    slirp4netns \
    fuse-overlayfs

echo -e "${GREEN}✓ Downloaded $(ls -1 *.deb 2>/dev/null | wc -l) .deb packages${NC}"

#---------------------------------------------
# STEP 2: Pull and Save Docker Images
#---------------------------------------------
echo ""
echo -e "${YELLOW}[2/7] Downloading Docker images...${NC}"
cd "$WORK_DIR/docker-images"

# Array of required images
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
    echo "Saving $IMAGE to ${IMAGE_FILE}.tar.gz..."
    docker save "$IMAGE" | gzip > "${IMAGE_FILE}.tar.gz"
    
    # Verify
    if [ -f "${IMAGE_FILE}.tar.gz" ]; then
        SIZE=$(ls -lh "${IMAGE_FILE}.tar.gz" | awk '{print $5}')
        echo -e "${GREEN}✓ Saved: ${IMAGE_FILE}.tar.gz (${SIZE})${NC}"
    else
        echo -e "${RED}✗ Failed to save $IMAGE${NC}"
    fi
done

#---------------------------------------------
# STEP 3: Download AVMS Source Code
#---------------------------------------------
echo ""
echo -e "${YELLOW}[3/7] Preparing AVMS source code...${NC}"
cd "$WORK_DIR/avms-source"

# Create a sample docker-compose.yml if you don't have one
cat > docker-compose.yml << 'COMPOSE_EOF'
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
      - mongo-config:/data/configdb
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
    environment:
      NODE_ENV: production
      MONGODB_URI: mongodb://admin:avms_admin_pass_2024@mongodb:27017/avms?authSource=admin
      JWT_SECRET: your-secret-key-change-in-production
      PORT: 3000
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
      - ./nginx.conf:/etc/nginx/nginx.conf:ro
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
    environment:
      MONGODB_URL: mongodb://admin:avms_admin_pass_2024@mongodb:27017/avms?authSource=admin
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
      - caddy-data:/data
      - caddy-config:/config
    depends_on:
      - frontend
      - backend
      - fastapi
    networks:
      - avms-network

volumes:
  mongo-data:
  mongo-config:
  caddy-data:
  caddy-config:

networks:
  avms-network:
    driver: bridge
COMPOSE_EOF

# Create Caddyfile
cat > Caddyfile << 'CADDY_EOF'
:8088 {
    # Frontend
    handle /* {
        reverse_proxy frontend:80
    }

    # Backend API
    handle /api/* {
        reverse_proxy backend:3000
    }

    # WebSocket support
    handle /socket.io/* {
        reverse_proxy backend:3000 {
            header_up Upgrade {http.request.header.Upgrade}
            header_up Connection {http.request.header.Connection}
        }
    }

    # FastAPI
    handle /py/* {
        reverse_proxy fastapi:8000
    }

    # Static files from test-data
    handle /static/* {
        file_server
        root /srv
    }
}
CADDY_EOF

# Create sample application directories
mkdir -p backend frontend/dist fastapi

# Create sample backend package.json
cat > backend/package.json << 'PKG_EOF'
{
  "name": "avms-backend",
  "version": "1.0.0",
  "scripts": {
    "start": "node server.js"
  },
  "dependencies": {
    "express": "^4.18.0",
    "mongodb": "^5.0.0"
  }
}
PKG_EOF

# Create sample backend server
cat > backend/server.js << 'SERVER_EOF'
const express = require('express');
const app = express();
const port = process.env.PORT || 3000;

app.get('/api/health', (req, res) => {
  res.json({ status: 'healthy', service: 'backend', timestamp: new Date() });
});

app.get('/api/vehicles', (req, res) => {
  res.json([
    { vehicleId: 'VH-001', plateNumber: 'ABC-1234' },
    { vehicleId: 'VH-002', plateNumber: 'XYZ-5678' }
  ]);
});

app.listen(port, () => {
  console.log(`AVMS Backend running on port ${port}`);
});
SERVER_EOF

# Create FastAPI requirements
cat > fastapi/requirements.txt << 'REQ_EOF'
fastapi==0.104.0
uvicorn==0.24.0
pymongo==4.5.0
pydantic==2.4.0
REQ_EOF

# Create FastAPI main.py
cat > fastapi/main.py << 'FASTAPI_EOF'
from fastapi import FastAPI
from datetime import datetime

app = FastAPI(title="AVMS FastAPI Service")

@app.get("/health")
@app.get("/py/health")
def health_check():
    return {
        "status": "healthy",
        "service": "fastapi",
        "timestamp": datetime.now().isoformat()
    }
FASTAPI_EOF

# Create sample frontend
cat > frontend/dist/index.html << 'HTML_EOF'
<!DOCTYPE html>
<html>
<head>
    <title>AVMS - Vehicle Management System</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 40px; }
        h1 { color: #2c3e50; }
    </style>
</head>
<body>
    <h1>AVMS - Advanced Vehicle Management System</h1>
    <p>Installation successful! This is the default page.</p>
    <ul>
        <li><a href="/test.html">Run Installation Tests</a></li>
        <li><a href="/api/health">Check Backend API</a></li>
        <li><a href="/py/health">Check FastAPI</a></li>
    </ul>
</body>
</html>
HTML_EOF

echo -e "${GREEN}✓ AVMS source structure created${NC}"

#---------------------------------------------
# STEP 4: Create All Scripts
#---------------------------------------------
echo ""
echo -e "${YELLOW}[4/7] Creating installation scripts...${NC}"
cd "$WORK_DIR/scripts"

# Create check-prerequisites.sh
cat > check-prerequisites.sh << 'PREREQ_EOF'
#!/bin/bash
# [INSERT THE FULL PREREQUISITE CHECK SCRIPT FROM EARLIER]
PREREQ_EOF

# Create install.sh
cat > install.sh << 'INSTALL_EOF'
#!/bin/bash
# [INSERT THE FULL INSTALL SCRIPT FROM EARLIER]
INSTALL_EOF

# Create load-test-data.sh
cat > load-test-data.sh << 'TESTDATA_EOF'
#!/bin/bash
# [INSERT THE FULL TEST DATA LOADER SCRIPT FROM EARLIER]
TESTDATA_EOF

# Create verify-installation.sh
cat > verify-installation.sh << 'VERIFY_EOF'
#!/bin/bash
# [INSERT THE FULL VERIFICATION SCRIPT FROM EARLIER]
VERIFY_EOF

# Make all scripts executable
chmod +x *.sh

echo -e "${GREEN}✓ Created $(ls -1 *.sh | wc -l) installation scripts${NC}"

#---------------------------------------------
# STEP 5: Create Test Data
#---------------------------------------------
echo ""
echo -e "${YELLOW}[5/7] Creating test data files...${NC}"
cd "$WORK_DIR/test-data"

# Create init-mongo.js
cat > init-mongo.js << 'MONGO_EOF'
// [INSERT THE FULL MONGO INIT SCRIPT FROM EARLIER]
MONGO_EOF

# Create seed-data.json
cat > seed-data.json << 'SEED_EOF'
// [INSERT THE FULL SEED DATA JSON FROM EARLIER]
SEED_EOF

# Create sample files
cat > sample-files/test.html << 'TEST_EOF'
// [INSERT THE FULL TEST HTML FROM EARLIER]
TEST_EOF

cat > sample-files/sample-vehicles.json << 'SAMPLE_EOF'
// [INSERT THE SAMPLE VEHICLES JSON FROM EARLIER]
SAMPLE_EOF

echo -e "${GREEN}✓ Test data files created${NC}"

#---------------------------------------------
# STEP 6: Create Documentation
#---------------------------------------------
echo ""
echo -e "${YELLOW}[6/7] Creating documentation...${NC}"
cd "$WORK_DIR"

cat > README.txt << 'README_EOF'
========================================
AVMS OFFLINE INSTALLATION PACKAGE
========================================

Version: 1.0.0
Date: $(date)

CONTENTS:
---------
- docker-debs/      : Docker installation packages (.deb files)
- docker-images/    : Docker container images (.tar.gz)
- avms-source/      : Application source code
- scripts/          : Installation and utility scripts
- test-data/        : Sample data for testing

REQUIREMENTS:
-------------
- Ubuntu 22.04 LTS or compatible
- 4GB RAM minimum (8GB recommended)
- 20GB free disk space
- Root/sudo access

INSTALLATION:
-------------
1. Mount DVD: sudo mount /dev/sr0 /mnt
2. Copy files: cp -r /mnt/* /opt/avms-install/
3. Navigate: cd /opt/avms-install
4. Check system: bash scripts/check-prerequisites.sh
5. Install: bash scripts/install.sh
6. Load test data: bash scripts/load-test-data.sh
7. Verify: bash scripts/verify-installation.sh

ACCESS:
-------
After installation, access AVMS at:
http://YOUR-SERVER-IP:8088

TROUBLESHOOTING:
----------------
- View logs: docker compose logs -f
- Restart services: docker compose restart
- Check status: docker compose ps

For issues, check the installation log files.
README_EOF

# Create offline installation guide
cat > OFFLINE_INSTALL_GUIDE.md << 'GUIDE_EOF'
# AVMS Offline Installation Guide

## Pre-Installation Checklist

- [ ] Ubuntu 22.04 LTS or compatible OS
- [ ] 4GB RAM minimum
- [ ] 20GB free disk space
- [ ] Root/sudo access
- [ ] DVD drive available and working
- [ ] No conflicting services on ports: 8088, 3000, 8000, 27017

## Step-by-Step Installation

[Full installation steps here...]
GUIDE_EOF

echo -e "${GREEN}✓ Documentation created${NC}"

#---------------------------------------------
# STEP 7: Verify and Create ISO
#---------------------------------------------
echo ""
echo -e "${YELLOW}[7/7] Creating verification files and ISO...${NC}"

# Create MD5 checksums
echo "Creating checksums..."
find . -type f -exec md5sum {} \; > CHECKSUMS.md5

# Create verification script
cat > verify-package.sh << 'VERIFY_PKG_EOF'
#!/bin/bash
echo "Verifying package integrity..."
md5sum -c CHECKSUMS.md5
if [ $? -eq 0 ]; then
    echo "✓ Package verification PASSED"
else
    echo "✗ Package verification FAILED"
fi
VERIFY_PKG_EOF
chmod +x verify-package.sh

# Show package statistics
echo ""
echo -e "${BLUE}Package Statistics:${NC}"
echo "------------------------"
echo "Docker packages: $(ls -1 docker-debs/*.deb 2>/dev/null | wc -l) files"
echo "Docker images: $(ls -1 docker-images/*.tar.gz 2>/dev/null | wc -l) files"
echo "Scripts: $(ls -1 scripts/*.sh 2>/dev/null | wc -l) files"
echo ""
echo "Size breakdown:"
du -sh docker-debs/ docker-images/ avms-source/ scripts/ test-data/
echo ""
TOTAL_SIZE=$(du -sh . | awk '{print $1}')
echo -e "${GREEN}Total package size: $TOTAL_SIZE${NC}"

# Check if size fits on DVD
SIZE_MB=$(du -sm . | awk '{print $1}')
if [ "$SIZE_MB" -lt 4400 ]; then
    echo -e "${GREEN}✓ Package fits on single-layer DVD (4.7GB)${NC}"
else
    echo -e "${YELLOW}! Package size exceeds single-layer DVD capacity${NC}"
fi

# Create ISO image
echo ""
echo -e "${BLUE}Creating ISO image...${NC}"

# Install genisoimage if not present
if ! command -v genisoimage &> /dev/null; then
    echo "Installing genisoimage..."
    sudo apt-get install -y genisoimage
fi

# Create ISO
ISO_FILE="$HOME/avms-offline-installer-$(date +%Y%m%d).iso"
genisoimage \
    -o "$ISO_FILE" \
    -R -J \
    -V "AVMS_INSTALLER" \
    -publisher "AVMS" \
    -p "AVMS Team" \
    -quiet \
    .

if [ -f "$ISO_FILE" ]; then
    ISO_SIZE=$(ls -lh "$ISO_FILE" | awk '{print $5}')
    echo ""
    echo -e "${GREEN}╔═══════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║           ISO CREATION SUCCESSFUL!                        ║${NC}"
    echo -e "${GREEN}╚═══════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo "  ISO File: $ISO_FILE"
    echo "  Size: $ISO_SIZE"
    echo ""
    echo "  Next steps:"
    echo "  1. Burn to DVD: growisofs -Z /dev/sr0=$ISO_FILE"
    echo "  2. Or use GUI tools: Brasero, K3b, etc."
    echo ""
    
    # Verify ISO
    echo "Verifying ISO contents..."
    isoinfo -d -i "$ISO_FILE" | grep "Volume id"
else
    echo -e "${RED}✗ ISO creation failed!${NC}"
    exit 1
fi

echo ""
echo -e "${GREEN}Package building complete!${NC}"
echo "Log saved to: $LOG_FILE"