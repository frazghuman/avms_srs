#!/bin/bash
# build-offline-package-universal.sh

#=============================================
# Universal AVMS Package Builder
# Works on both Mac and Linux
#=============================================

set -e

# Detect OS
OS="unknown"
if [[ "$OSTYPE" == "linux-gnu"* ]]; then
    OS="linux"
elif [[ "$OSTYPE" == "darwin"* ]]; then
    OS="mac"
else
    echo "Unsupported OS: $OSTYPE"
    exit 1
fi

echo "Detected OS: $OS"

# Colors (work on both Mac and Linux)
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

WORK_DIR="$HOME/avms-offline-install"

#---------------------------------------------
# Common functions for both OS
#---------------------------------------------
create_directories() {
    echo "Creating directory structure..."
    mkdir -p "$WORK_DIR"/{docker-debs,docker-images,avms-source,scripts,test-data}
}

pull_docker_images() {
    echo "Pulling Docker images..."
    cd "$WORK_DIR/docker-images"
    
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
        IMAGE_FILE=$(echo "$IMAGE" | tr ':/' '-')
        docker save "$IMAGE" | gzip > "${IMAGE_FILE}.tar.gz"
    done
}

create_application_files() {
    echo "Creating application files..."
    # [Same application file creation code as before]
}

#---------------------------------------------
# OS-specific functions
#---------------------------------------------
download_deb_packages_linux() {
    echo "Downloading .deb packages on Linux..."
    cd "$WORK_DIR/docker-debs"
    apt-get download docker-ce docker-ce-cli containerd.io docker-compose-plugin
}

download_deb_packages_mac() {
    echo "Using Docker to download .deb packages on Mac..."
    
    # Create download script
    cat > "$WORK_DIR/download-debs.sh" << 'EOF'
#!/bin/bash
apt-get update
cd /packages
apt-get download docker-ce docker-ce-cli containerd.io docker-compose-plugin
EOF
    
    # Run Ubuntu container to download packages
    docker run --rm \
        -v "$WORK_DIR/docker-debs:/packages" \
        ubuntu:22.04 \
        bash -c "bash /packages/../download-debs.sh"
}

create_iso_linux() {
    echo "Creating ISO on Linux..."
    cd "$WORK_DIR"
    
    # Install genisoimage if needed
    if ! command -v genisoimage &> /dev/null; then
        sudo apt-get install -y genisoimage
    fi
    
    genisoimage -o "$HOME/avms-installer.iso" \
        -R -J -V "AVMS_INSTALLER" .
}

create_iso_mac() {
    echo "Creating ISO on Mac..."
    cd "$WORK_DIR"
    
    # Use hdiutil (Mac's native tool)
    hdiutil makehybrid -o "$HOME/avms-installer.iso" \
        -iso -joliet \
        -default-volume-name "AVMS_INSTALLER" \
        "$WORK_DIR"
}

#---------------------------------------------
# Main execution
#---------------------------------------------
main() {
    echo -e "${BLUE}Starting AVMS Offline Package Builder${NC}"
    echo "Operating System: $OS"
    echo ""
    
    # Common steps
    create_directories
    pull_docker_images
    create_application_files
    
    # OS-specific steps
    if [ "$OS" == "linux" ]; then
        download_deb_packages_linux
        create_iso_linux
    elif [ "$OS" == "mac" ]; then
        download_deb_packages_mac
        create_iso_mac
    fi
    
    echo ""
    echo -e "${GREEN}Package creation complete!${NC}"
    echo "ISO location: $HOME/avms-installer.iso"
}

main