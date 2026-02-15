# AVMS — Offline Linux Server Prerequisite Setup Guide

> **Last Updated:** 12 February 2026

---

## Architecture & Ports

```
┌──────────────────────────────────────────────────────────────┐
│  Browser                                                     │
│  http://server-ip:8088   (or :4201 for direct Angular)       │
└────────────┬─────────────────────────────────────────────────┘
             │
      ┌──────▼──────┐
      │  Caddy :8088 │  (reverse proxy)
      └──┬───┬───┬──┘
         │   │   │
   ┌─────▼┐ ┌▼────────┐ ┌▼────────────┐
   │ Angular│ │ NestJS  │ │ FastAPI     │
   │ :4201  │ │ :3000   │ │ :8000       │
   └────────┘ └──┬──────┘ └──┬──────────┘
                 │            │
              ┌──▼────────────▼──┐
              │  MongoDB :27017  │
              └──────────────────┘
```

**Communication:**
- Angular ↔ NestJS: REST + Socket.IO (WebSocket for valuation progress)
- NestJS → FastAPI: HTTP (actuarial calculations)
- NestJS ↔ FastAPI → MongoDB: Direct connection via Mongoose / Motor+PyMongo

---

## Linux/Ubuntu Intel — System Prerequisites Installation

> **This section covers installing all required system software on a fresh Ubuntu 22.04/24.04 (x86_64 / Intel/AMD) server.**
> If the server has internet access, run these directly. If offline, download the `.deb` packages on an online machine first.

### A. System Updates & Essential Tools

```bash
sudo apt update && sudo apt upgrade -y
sudo apt install -y \
  curl \
  wget \
  git \
  build-essential \
  ca-certificates \
  gnupg \
  lsb-release \
  software-properties-common \
  tar \
  gzip \
  unzip \
  rsync \
  ufw \
  tmux \
  htop \
  lsof \
  net-tools
```

### B. Node.js 18.x (LTS)

```bash
# Add NodeSource repository
curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -

# Install
sudo apt install -y nodejs

# Verify
node --version   # Expected: v18.x.x
npm --version    # Expected: 9.x or 10.x
```

### C. Global npm Packages (Angular CLI & NestJS CLI)

```bash
# Install Angular CLI globally
sudo npm install -g @angular/cli@16

# Install NestJS CLI globally
sudo npm install -g @nestjs/cli

# Verify
ng version       # Expected: Angular CLI: 16.x.x
nest --version   # Expected: 9.x.x or 10.x.x
```

### D. Python 3.12

```bash
# Add deadsnakes PPA (for Ubuntu 22.04 which ships 3.10)
sudo add-apt-repository -y ppa:deadsnakes/ppa
sudo apt update

# Install Python 3.12 + venv + pip + dev headers
sudo apt install -y \
  python3.12 \
  python3.12-venv \
  python3.12-dev \
  python3-pip

# Set as default (optional)
sudo update-alternatives --install /usr/bin/python3 python3 /usr/bin/python3.12 1
sudo update-alternatives --config python3

# Verify
python3.12 --version   # Expected: 3.12.x
```

### E. MongoDB 7.0

```bash
# Import MongoDB GPG key
curl -fsSL https://www.mongodb.org/static/pgp/server-7.0.asc | \
  sudo gpg -o /usr/share/keyrings/mongodb-server-7.0.gpg --dearmor

# Add repository (Ubuntu 22.04 jammy)
echo "deb [ arch=amd64,arm64 signed-by=/usr/share/keyrings/mongodb-server-7.0.gpg ] \
  https://repo.mongodb.org/apt/ubuntu jammy/mongodb-org/7.0 multiverse" | \
  sudo tee /etc/apt/sources.list.d/mongodb-org-7.0.list

sudo apt update
sudo apt install -y mongodb-org

# Start & enable
sudo systemctl start mongod
sudo systemctl enable mongod

# Verify
mongosh --eval "db.runCommand({ping:1})"

# Create admin user (recommended)
mongosh <<EOF
use admin
db.createUser({
  user: "admin",
  pwd: "your_secure_password",
  roles: [{ role: "root", db: "admin" }]
})
EOF
```

### F. Docker & Docker Compose

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

### G. Caddy (Reverse Proxy)

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

### H. Google Chrome (Latest)

```bash
# Download and install Google Chrome
wget https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb

sudo dpkg -i google-chrome-stable_current_amd64.deb

# Fix any missing dependencies
sudo apt --fix-broken install -y

# Verify
google-chrome --version
```

For **offline install**, download the `.deb` on an online machine and transfer it:

```bash
# On online machine
wget https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb \
  -O offline-packages/google-chrome-stable_current_amd64.deb

# On offline server
sudo dpkg -i offline-packages/google-chrome-stable_current_amd64.deb
sudo apt --fix-broken install -y
```

### I. VS Code (Latest)

```bash
# Download and install VS Code
wget -qO- https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor > packages.microsoft.gpg
sudo install -D -o root -g root -m 644 packages.microsoft.gpg /etc/apt/keyrings/packages.microsoft.gpg

echo "deb [arch=amd64 signed-by=/etc/apt/keyrings/packages.microsoft.gpg] \
  https://packages.microsoft.com/repos/code stable main" | \
  sudo tee /etc/apt/sources.list.d/vscode.list > /dev/null

sudo apt update
sudo apt install -y code

# Verify
code --version
```

For **offline install**, download the `.deb` on an online machine and transfer it:

```bash
# On online machine — download from https://code.visualstudio.com/download
wget "https://code.visualstudio.com/sha/download?build=stable&os=linux-deb-x64" \
  -O offline-packages/code_latest_amd64.deb

# On offline server
sudo dpkg -i offline-packages/code_latest_amd64.deb
sudo apt --fix-broken install -y
```

### J. Summary — What Must Be Installed

| #  | Software            | Required Version          | Install Command Summary                        | Purpose                                           |
|----|---------------------|---------------------------|------------------------------------------------|---------------------------------------------------|
| 1  | **build-essential** | any                       | `apt install build-essential`                  | C/C++ compiler for native npm modules (bcrypt, etc.) |
| 2  | **curl, wget, git** | any                       | `apt install curl wget git`                    | Downloading & version control                     |
| 3  | **Node.js**         | 18.x LTS                 | NodeSource repo → `apt install nodejs`         | avms-frontend, avms-backend                       |
| 4  | **npm**             | 9.x+ (ships with Node)   | Comes with Node.js                             | Package management                                |
| 5  | **Angular CLI**     | 16.x                     | `npm install -g @angular/cli@16`               | Frontend build & serve                            |
| 6  | **NestJS CLI**      | 9.x / 10.x               | `npm install -g @nestjs/cli`                   | Backend build, generate modules/services          |
| 7  | **Python**          | 3.12.x                   | deadsnakes PPA → `apt install python3.12`      | avms-fastapi-docker                               |
| 8  | **pip + venv**      | (ships with Python)       | `apt install python3.12-venv`                  | Python virtual environments                       |
| 9  | **MongoDB**         | 7.0.x                    | MongoDB repo → `apt install mongodb-org`       | Database                                          |
| 10 | **Docker**          | 24.x+                    | Docker repo → `apt install docker-ce`          | Containerized deployment                          |
| 11 | **Docker Compose**  | v2.x (plugin)            | `apt install docker-compose-plugin`            | Multi-container orchestration                     |
| 12 | **Caddy**           | 2.x                      | Caddy repo → `apt install caddy`               | Reverse proxy (optional for dev)                  |
| 13 | **Google Chrome**   | latest                   | Download `.deb` → `dpkg -i`                    | Browser for testing & development                 |
| 14 | **VS Code**         | latest                   | Microsoft repo → `apt install code`            | Code editor / IDE                                 |
| 15 | **tmux**            | any                      | `apt install tmux`                             | Multiple terminals in one session                 |

---

## Project-Level Dependencies

> These are the npm and pip packages required by each AVMS project folder. Install them with `npm install` (Node.js projects) or `pip install -r requirements.txt` (Python project) after system prerequisites are in place.

### avms-frontend — package.json

```json
{
  "dependencies": {
    "@angular/animations": "^16.2.4",
    "@angular/common": "^16.2.4",
    "@angular/compiler": "^16.2.4",
    "@angular/core": "^16.2.4",
    "@angular/forms": "^16.2.4",
    "@angular/platform-browser": "^16.2.4",
    "@angular/platform-browser-dynamic": "^16.2.4",
    "@angular/router": "^16.2.4",
    "@fortawesome/fontawesome-free": "^6.3.0",
    "@types/xlsx": "^0.0.35",
    "bytes": "^3.1.2",
    "echarts": "^6.0.0",
    "filesize": "^10.0.7",
    "lodash": "^4.17.21",
    "ngx-echarts": "^16.2.0",
    "ngx-google-analytics": "^14.0.1",
    "primeicons": "^6.0.1",
    "primeng": "^16.3.1",
    "rxjs": "~7.8.0",
    "socket.io-client": "^4.8.1",
    "xlsx": "^0.18.5",
    "zone.js": "^0.13.1"
  },
  "devDependencies": {
    "@angular-devkit/build-angular": "^16.2.1",
    "@angular/cli": "~16.2.1",
    "@angular/compiler-cli": "^16.2.4",
    "@types/bytes": "^3.1.1",
    "@types/jasmine": "~4.3.0",
    "@types/lodash": "^4.14.197",
    "autoprefixer": "^10.4.14",
    "jasmine-core": "~4.5.0",
    "karma": "~6.4.0",
    "karma-chrome-launcher": "~3.1.0",
    "karma-coverage": "~2.2.0",
    "karma-jasmine": "~5.1.0",
    "karma-jasmine-html-reporter": "~2.0.0",
    "postcss": "^8.4.21",
    "tailwindcss": "^3.2.7",
    "tslib": "^2.6.2",
    "typescript": "~4.9.4"
  }
}
```

### avms-backend — package.json

```json
{
  "dependencies": {
    "@grpc/grpc-js": "^1.13.3",
    "@grpc/proto-loader": "^0.7.15",
    "@nestjs/common": "^9.0.0",
    "@nestjs/config": "^2.3.1",
    "@nestjs/core": "^9.0.0",
    "@nestjs/jwt": "^10.0.2",
    "@nestjs/mongoose": "^9.2.1",
    "@nestjs/passport": "^9.0.3",
    "@nestjs/platform-express": "^9.4.3",
    "@nestjs/platform-socket.io": "^9.4.3",
    "@nestjs/serve-static": "^4.0.0",
    "@nestjs/websockets": "^9.4.3",
    "axios": "^1.10.0",
    "bcrypt": "^5.1.0",
    "class-transformer": "^0.5.1",
    "class-validator": "^0.14.0",
    "dotenv": "^16.0.3",
    "exceljs": "^4.4.0",
    "express": "^4.18.2",
    "joi": "^17.8.3",
    "jsonwebtoken": "^9.0.0",
    "moment": "^2.30.1",
    "mongodb": "^5.0.1",
    "mongoose": "^6.10.0",
    "multer": "^1.4.5-lts.1",
    "passport-jwt": "^4.0.1",
    "path": "^0.12.7",
    "reflect-metadata": "^0.1.13",
    "rxjs": "^7.2.0",
    "socket.io": "^4.8.1",
    "uuid": "^9.0.0",
    "xlsx": "^0.18.5"
  },
  "devDependencies": {
    "@nestjs/cli": "^9.0.0",
    "@nestjs/schematics": "^9.0.0",
    "@nestjs/testing": "^9.0.0",
    "@types/bcrypt": "^5.0.0",
    "@types/express": "^4.17.13",
    "@types/jest": "29.2.4",
    "@types/node": "18.11.18",
    "@types/supertest": "^2.0.11",
    "@typescript-eslint/eslint-plugin": "^5.0.0",
    "@typescript-eslint/parser": "^5.0.0",
    "eslint": "^8.0.1",
    "eslint-config-prettier": "^8.3.0",
    "eslint-plugin-prettier": "^4.0.0",
    "jest": "29.3.1",
    "prettier": "^2.3.2",
    "source-map-support": "^0.5.20",
    "supertest": "^6.1.3",
    "ts-jest": "29.0.3",
    "ts-loader": "^9.2.3",
    "ts-node": "^10.0.0",
    "tsconfig-paths": "4.1.1",
    "typescript": "^4.7.4"
  }
}
```

### avms-fastapi-docker — requirements.txt

```
uvicorn
fastapi
motor
pymongo
python-dotenv
annotated-types==0.7.0
debugpy==1.8.13
markdown-it-py==3.0.0
mdurl==0.1.2
numpy==2.2.3
pandas==2.2.3
prettytable==3.15.1
pydantic==2.10.6
pydantic_core==2.27.2
Pygments==2.19.1
python-dateutil==2.9.0.post0
pytz==2025.1
rich==13.9.4
six==1.17.0
tabulate==0.9.0
typing_extensions==4.12.2
tzdata==2025.1
wcwidth==0.2.13
grpcio==1.67.1
grpcio-tools==1.67.1
protobuf==5.29.1
requests==2.32.4
httpx==0.25.2
```

---

## Reverse Proxy (Caddy) Configuration

For development, you can unify all services behind Caddy on port 8088.

Save as `~/Caddyfile-avms`:

```caddyfile
:8088 {
    # Angular frontend
    handle {
        reverse_proxy 127.0.0.1:4201
    }

    # NestJS API
    handle /api/* {
        reverse_proxy 127.0.0.1:3000
    }

    # Socket.IO (WebSocket)
    handle /api/socket.io/* {
        reverse_proxy 127.0.0.1:3000
    }

    # FastAPI (if needed directly)
    handle /fastapi/* {
        uri strip_prefix /fastapi
        reverse_proxy 127.0.0.1:8000
    }
}
```

Run:

```bash
caddy run --config ~/Caddyfile-avms
# Access everything at http://server-ip:8088
```

---

## VS Code Extensions

### Recommended Extensions

| Extension | ID | Purpose |
|-----------|-----|---------|
| Python | `ms-python.python` | Python language support |
| Debugpy | `ms-python.debugpy` | Python debugging |
| Angular Language Service | `Angular.ng-template` | Angular template support |
| TypeScript Next | `ms-vscode.vscode-typescript-next` | TypeScript language support |
| MongoDB | `mongodb.mongodb-vscode` | MongoDB database management |
| Prettier | `esbenp.prettier-vscode` | Code formatting |
| Tailwind CSS IntelliSense | `bradlc.vscode-tailwindcss` | Tailwind CSS support |
| Remote - SSH | `ms-vscode-remote.remote-ssh` | Remote development via SSH |

### Offline Installation

Download `.vsix` files on an online machine from [VS Code Marketplace](https://marketplace.visualstudio.com/), then install on the offline server:

```bash
code --install-extension /path/to/extension.vsix
```

---

## Troubleshooting

### Common Issues

| Issue | Cause | Solution |
|-------|-------|---------|
| `npm ERR! network request` | npm trying to reach registry offline | Don't run `npm install` without internet; use pre-packed `node_modules` |
| `bcrypt` or native module error | Built on macOS, running on Linux | Run `npm rebuild bcrypt --build-from-source` |
| MongoDB connection refused | Service not started | `docker ps` or `systemctl status mongod` |
| `JavaScript heap out of memory` | Not enough RAM for Node.js | `export NODE_OPTIONS="--max-old-space-size=4096"` |
| Docker `pull access denied` | Base image not loaded | Run `docker load -i <image>.tar` first |
| `EADDRINUSE` port conflict | Port already in use | `lsof -i :<port>` → `kill <pid>` |

### Firewall Rules

```bash
# Development — allow all AVMS ports
sudo ufw allow 4201/tcp comment "Angular Frontend"
sudo ufw allow 3000/tcp comment "NestJS Backend"
sudo ufw allow 8000/tcp comment "FastAPI"
sudo ufw allow 8088/tcp comment "Caddy Proxy"

# Production — only expose the proxy port
sudo ufw allow 80/tcp comment "Frontend (Docker/Nginx)"
# Keep MongoDB restricted to localhost
sudo ufw deny 27017/tcp comment "Block external MongoDB"

sudo ufw enable
sudo ufw status verbose
```

---

*This document covers the system-level prerequisites for running AVMS on Ubuntu Intel (x86_64) servers.*
