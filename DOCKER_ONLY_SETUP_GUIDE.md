# AVMS — Docker-Only Deployment Guide

> **Last Updated:** 13 February 2026

This guide covers running AVMS using Docker containers only. No need to install Node.js, Python, or MongoDB directly on the host system.

---

## Architecture & Ports

```
┌──────────────────────────────────────────────────────────────┐
│  Browser                                                     │
│  http://server-ip:8088                                       │
└────────────┬─────────────────────────────────────────────────┘
             │
      ┌──────▼──────┐
      │  Caddy :8088 │  (reverse proxy - host or container)
      └──┬───┬───┬──┘
         │   │   │
   ┌─────▼┐ ┌▼────────┐ ┌▼────────────┐
   │ Angular│ │ NestJS  │ │ FastAPI     │
   │ :4201  │ │ :3000   │ │ :8000       │
   │(Docker)│ │(Docker) │ │(Docker)     │
   └────────┘ └──┬──────┘ └──┬──────────┘
                 │            │
              ┌──▼────────────▼──┐
              │  MongoDB :27017  │
              │    (Docker)      │
              └──────────────────┘
```

---

## System Prerequisites (Minimal)

### A. System Updates & Essential Tools

```bash
sudo apt update && sudo apt upgrade -y
sudo apt install -y \
  curl \
  wget \
  git \
  ca-certificates \
  gnupg \
  lsb-release \
  tar \
  gzip \
  unzip \
  rsync \
  ufw
```

### B. Docker & Docker Compose

```bash
# Add Docker GPG key
sudo install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | \
  sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
sudo chmod a+r /etc/apt/keyrings/docker.gpg

# Add repository
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
  https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

sudo apt update
sudo apt install -y \
  docker-ce \
  docker-ce-cli \
  containerd.io \
  docker-buildx-plugin \
  docker-compose-plugin

# Allow non-root user to run Docker
sudo usermod -aG docker $USER
newgrp docker

# Verify
docker --version          # Expected: 24.x+
docker compose version    # Expected: v2.x+
docker run hello-world
```

### C. Caddy (Reverse Proxy) — Optional on Host

If you prefer running Caddy on the host instead of in a container:

```bash
sudo apt install -y debian-keyring debian-archive-keyring apt-transport-https
curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/gpg.key' | \
  sudo gpg --dearmor -o /usr/share/keyrings/caddy-stable-archive-keyring.gpg
curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/debian.deb.txt' | \
  sudo tee /etc/apt/sources.list.d/caddy-stable.list

sudo apt update
sudo apt install -y caddy

# Verify
caddy version
```

---

## Summary — What Must Be Installed

| #  | Software            | Required Version | Purpose                          |
|----|---------------------|------------------|----------------------------------|
| 1  | **curl, wget, git** | any              | Downloading & version control    |
| 2  | **Docker**          | 24.x+            | Container runtime                |
| 3  | **Docker Compose**  | v2.x (plugin)    | Multi-container orchestration    |
| 4  | **Caddy**           | 2.x (optional)   | Reverse proxy (can run in Docker)|

---

### Caddyfile (for Docker)

```caddyfile
:8088 {
    # Angular frontend
    handle {
        reverse_proxy frontend:80
    }

    # NestJS API
    handle_path /api/* {
        reverse_proxy backend:3000
    }

    # Socket.IO (WebSocket)
    handle /api/socket.io/* {
        reverse_proxy backend:3000 {
            header_up Connection {>Connection}
            header_up Upgrade {>Upgrade}
        }
    }

    # FastAPI
    handle_path /py/* {
        reverse_proxy fastapi:8000
    }
}
```

---

## Running the Application

### Start All Services

```bash
# Build and start all containers
docker compose up -d --build

# View logs
docker compose logs -f

# Check status
docker compose ps
```

---

## Offline Deployment

For servers without internet access:

### 1. Save Docker Images (on online machine)

```bash
# Pull all required images
docker pull mongo:7.0
docker pull node:18-alpine
docker pull python:3.12-slim
docker pull nginx:alpine
docker pull caddy:2-alpine

# Save to tar files
docker save mongo:7.0 -o mongo-7.0.tar
docker save node:18-alpine -o node-18-alpine.tar
docker save python:3.12-slim -o python-3.12-slim.tar
docker save nginx:alpine -o nginx-alpine.tar
docker save caddy:2-alpine -o caddy-2-alpine.tar
```

### 2. Transfer to Offline Server

```bash
# Copy tar files via USB or secure transfer
rsync -avz *.tar user@offline-server:/path/to/images/
```

### 3. Load Images (on offline server)

```bash
docker load -i mongo-7.0.tar
docker load -i node-18-alpine.tar
docker load -i python-3.12-slim.tar
docker load -i nginx-alpine.tar
docker load -i caddy-2-alpine.tar

# Verify
docker images
```

### 4. Build Application Images Offline

After loading base images, build the application:

```bash
docker compose build
docker compose up -d
```

---

## Firewall Rules

```bash
# Only expose the proxy port
sudo ufw allow 8088/tcp comment "Caddy Proxy"

# Block direct access to internal services (optional)
sudo ufw deny 4201/tcp comment "Block direct Angular"
sudo ufw deny 3000/tcp comment "Block direct NestJS"
sudo ufw deny 8000/tcp comment "Block direct FastAPI"
sudo ufw deny 27017/tcp comment "Block external MongoDB"

sudo ufw enable
sudo ufw status verbose
```

---

## Troubleshooting

| Issue | Cause | Solution |
|-------|-------|----------|
| Container won't start | Port conflict | `docker compose down` then `docker compose up -d` |
| MongoDB connection refused | Container not ready | Wait or check `docker compose logs mongodb` |
| `docker: permission denied` | User not in docker group | `sudo usermod -aG docker $USER && newgrp docker` |
| Image pull failed (offline) | Base image not loaded | `docker load -i <image>.tar` first |
| Build fails | Missing base image | Load all base images before building |
| Slow performance | Not enough resources | Increase Docker memory/CPU limits |

### Useful Commands

```bash
# View all container logs
docker compose logs -f

# View specific service logs
docker compose logs -f backend

# Enter a container shell
docker compose exec backend sh
docker compose exec mongodb mongosh

# Check container resource usage
docker stats

# Remove all stopped containers and unused images
docker system prune -a
```


*This document covers Docker-only deployment for AVMS.*
