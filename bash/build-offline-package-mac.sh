# Create the complete Mac-compatible version
cat > build-offline-package-mac.sh << 'MAINSCRIPT'
#!/bin/bash

#=============================================
# AVMS Offline Package Builder for Mac
# Creates a complete offline installation ISO
# Target: Ubuntu 22.04 LTS server
#=============================================

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

WORK_DIR="$HOME/avms-offline-install"

echo -e "${BLUE}╔═══════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║  AVMS Offline Package Builder (Mac)       ║${NC}"
echo -e "${BLUE}╚═══════════════════════════════════════════╝${NC}"
echo ""

# Pre-flight checks
echo -e "${YELLOW}[Pre-flight] Checking requirements...${NC}"

if ! command -v docker &> /dev/null; then
    echo -e "${RED}✗ Docker not installed! Install Docker Desktop for Mac${NC}"
    exit 1
fi

if ! docker info &>/dev/null; then
    echo -e "${RED}✗ Docker Desktop is not running! Start it first.${NC}"
    exit 1
fi

echo -e "${GREEN}✓ Docker is running${NC}"
echo ""

# Clean and create directories
rm -rf "$WORK_DIR"
mkdir -p "$WORK_DIR"/{docker-debs,docker-images,avms-source/{backend,frontend/dist,fastapi},scripts,test-data/sample-files}

#=============================================
# STEP 1: Download .deb packages via Ubuntu container
#=============================================
echo -e "${YELLOW}[1/8] Downloading Docker .deb packages via Ubuntu container...${NC}"

cat > "$WORK_DIR/docker-debs/_download.sh" << 'DEBDL'
#!/bin/bash
set -e
apt-get update -qq
apt-get install -y -qq ca-certificates curl gnupg lsb-release > /dev/null 2>&1

install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | \
    gpg --dearmor -o /etc/apt/keyrings/docker.gpg
chmod a+r /etc/apt/keyrings/docker.gpg

echo "deb [arch=amd64 signed-by=/etc/apt/keyrings/docker.gpg] \
    https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | \
    tee /etc/apt/sources.list.d/docker.list > /dev/null

apt-get update -qq

cd /packages

apt-get download \
    docker-ce \
    docker-ce-cli \
    containerd.io \
    docker-buildx-plugin \
    docker-compose-plugin 2>/dev/null || true

apt-get download \
    pigz xz-utils libseccomp2 libapparmor1 libltdl7 \
    iptables libip4tc2 libip6tc2 libnfnetlink0 \
    libnetfilter-conntrack3 slirp4netns uidmap \
    dbus-user-session fuse-overlayfs 2>/dev/null || true

apt-get download \
    ca-certificates curl gnupg lsb-release wget \
    git rsync ufw tar gzip unzip 2>/dev/null || true

echo ""
echo "Downloaded $(ls -1 *.deb 2>/dev/null | wc -l) packages"
DEBDL

docker run --rm --platform linux/amd64 \
    -v "$WORK_DIR/docker-debs:/packages" \
    ubuntu:22.04 \
    bash /packages/_download.sh

rm -f "$WORK_DIR/docker-debs/_download.sh"
DEB_COUNT=$(ls -1 "$WORK_DIR/docker-debs/"*.deb 2>/dev/null | wc -l | tr -d ' ')
echo -e "${GREEN}✓ Downloaded $DEB_COUNT .deb packages${NC}"

#=============================================
# STEP 2: Pull and save Docker images
#=============================================
echo ""
echo -e "${YELLOW}[2/8] Pulling and saving Docker images (this takes a few minutes)...${NC}"

cd "$WORK_DIR/docker-images"

IMAGES=(
    "mongo:7.0"
    "node:18-alpine"
    "python:3.12-slim"
    "nginx:alpine"
    "caddy:2-alpine"
)

for IMAGE in "${IMAGES[@]}"; do
    echo -n "  Pulling $IMAGE... "
    docker pull --platform linux/amd64 "$IMAGE" > /dev/null 2>&1
    echo -n "saving... "
    IMAGE_FILE=$(echo "$IMAGE" | tr ':/' '-')
    docker save "$IMAGE" | gzip > "${IMAGE_FILE}.tar.gz"
    SIZE=$(ls -lh "${IMAGE_FILE}.tar.gz" | awk '{print $5}')
    echo -e "${GREEN}done ($SIZE)${NC}"
done

echo -e "${GREEN}✓ All images saved${NC}"

#=============================================
# STEP 3: Create docker-compose.yml
#=============================================
echo ""
echo -e "${YELLOW}[3/8] Creating application files...${NC}"

cd "$WORK_DIR/avms-source"

cat > docker-compose.yml << 'DCEOF'
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
    healthcheck:
      test: echo 'db.runCommand("ping").ok' | mongosh --quiet
      interval: 30s
      timeout: 10s
      retries: 5
      start_period: 40s

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
      PORT: 3000
    ports:
      - "3000:3000"
    depends_on:
      mongodb:
        condition: service_healthy
    networks:
      - avms-network
    command: sh -c "cd /app && npm install --production && node server.js"

  frontend:
    image: nginx:alpine
    container_name: avms-frontend
    restart: unless-stopped
    volumes:
      - ./frontend/dist:/usr/share/nginx/html:ro
      - ./frontend/nginx.conf:/etc/nginx/conf.d/default.conf:ro
      - ./test-data/sample-files:/usr/share/nginx/html/static:ro
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
      mongodb:
        condition: service_healthy
    networks:
      - avms-network
    command: sh -c "pip install --no-cache-dir -r requirements.txt && uvicorn main:app --host 0.0.0.0 --port 8000"

  caddy:
    image: caddy:2-alpine
    container_name: avms-proxy
    restart: unless-stopped
    ports:
      - "8088:8088"
    volumes:
      - ./Caddyfile:/etc/caddy/Caddyfile:ro
    depends_on:
      - frontend
      - backend
      - fastapi
    networks:
      - avms-network

volumes:
  mongo-data:

networks:
  avms-network:
    driver: bridge
DCEOF

cat > Caddyfile << 'CADDYEOF'
:8088 {
    handle /api/socket.io/* {
        reverse_proxy backend:3000 {
            header_up Connection {>Connection}
            header_up Upgrade {>Upgrade}
        }
    }
    handle_path /api/* {
        reverse_proxy backend:3000
    }
    handle_path /py/* {
        reverse_proxy fastapi:8000
    }
    handle {
        reverse_proxy frontend:80
    }
}
CADDYEOF

#=============================================
# STEP 4: Create Backend
#=============================================
cat > backend/package.json << 'BPKG'
{
  "name": "avms-backend",
  "version": "1.0.0",
  "scripts": { "start": "node server.js" },
  "dependencies": {
    "express": "^4.18.2",
    "mongodb": "^6.3.0",
    "cors": "^2.8.5"
  }
}
BPKG

cat > backend/server.js << 'BSERVER'
const express = require('express');
const cors = require('cors');
const { MongoClient } = require('mongodb');

const app = express();
const port = process.env.PORT || 3000;
const mongoUri = process.env.MONGODB_URI || 'mongodb://admin:avms_admin_pass_2024@localhost:27017/avms?authSource=admin';

app.use(cors());
app.use(express.json());

let db;

async function connectDB() {
    try {
        const client = new MongoClient(mongoUri);
        await client.connect();
        db = client.db('avms');
        console.log('Connected to MongoDB');
    } catch (err) {
        console.error('MongoDB error:', err.message);
        setTimeout(connectDB, 5000);
    }
}

app.get('/health', (req, res) => {
    res.json({ status: 'healthy', service: 'backend', database: db ? 'connected' : 'disconnected', timestamp: new Date().toISOString() });
});

app.get('/vehicles', async (req, res) => {
    try {
        if (!db) return res.status(503).json({ error: 'DB not connected' });
        const vehicles = await db.collection('vehicles').find({}).toArray();
        res.json(vehicles);
    } catch (err) { res.status(500).json({ error: err.message }); }
});

app.get('/users', async (req, res) => {
    try {
        if (!db) return res.status(503).json({ error: 'DB not connected' });
        const users = await db.collection('users').find({}, { projection: { password: 0 } }).toArray();
        res.json(users);
    } catch (err) { res.status(500).json({ error: err.message }); }
});

app.get('/maintenance', async (req, res) => {
    try {
        if (!db) return res.status(503).json({ error: 'DB not connected' });
        const records = await db.collection('maintenance_records').find({}).toArray();
        res.json(records);
    } catch (err) { res.status(500).json({ error: err.message }); }
});

app.get('/vehicles/:id', async (req, res) => {
    try {
        if (!db) return res.status(503).json({ error: 'DB not connected' });
        const v = await db.collection('vehicles').findOne({ vehicleId: req.params.id });
        if (!v) return res.status(404).json({ error: 'Not found' });
        res.json(v);
    } catch (err) { res.status(500).json({ error: err.message }); }
});

connectDB().then(() => {
    app.listen(port, '0.0.0.0', () => console.log(`Backend on port ${port}`));
});
BSERVER

#=============================================
# STEP 5: Create Frontend
#=============================================
cat > frontend/nginx.conf << 'NGEOF'
server {
    listen 80;
    root /usr/share/nginx/html;
    index index.html;
    location / { try_files $uri $uri/ /index.html; }
    location /static/ { alias /usr/share/nginx/html/static/; }
}
NGEOF

cat > frontend/dist/index.html << 'FEHTML'
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>AVMS - Vehicle Management</title>
    <style>
        *{margin:0;padding:0;box-sizing:border-box}
        body{font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',sans-serif;background:#f0f2f5}
        .header{background:#1a73e8;color:#fff;padding:20px 40px}
        .container{max-width:1000px;margin:30px auto;padding:0 20px}
        .card{background:#fff;border-radius:8px;padding:24px;margin-bottom:20px;box-shadow:0 1px 3px rgba(0,0,0,.1)}
        .card h2{color:#333;margin-bottom:16px}
        .status{display:inline-block;padding:4px 12px;border-radius:12px;font-size:13px;font-weight:500}
        .pass{background:#e6f4ea;color:#137333}
        .fail{background:#fce8e6;color:#c5221f}
        .loading{background:#e8f0fe;color:#1967d2}
        .test-row{display:flex;justify-content:space-between;align-items:center;padding:12px 0;border-bottom:1px solid #f0f0f0}
        .btn{padding:10px 24px;border:none;border-radius:6px;cursor:pointer;font-size:14px;font-weight:500;margin:4px}
        .btn-primary{background:#1a73e8;color:#fff}
        .btn-primary:hover{background:#1557b0}
        table{width:100%;border-collapse:collapse;margin-top:12px}
        th,td{padding:10px 12px;text-align:left;border-bottom:1px solid #f0f0f0;font-size:14px}
        th{background:#f8f9fa;font-weight:600;color:#5f6368}
        pre{background:#f8f9fa;padding:12px;border-radius:6px;overflow-x:auto;font-size:13px;margin-top:8px}
    </style>
</head>
<body>
    <div class="header"><h1>🚗 AVMS - Advanced Vehicle Management System</h1></div>
    <div class="container">
        <div class="card">
            <h2>System Health Check</h2>
            <button class="btn btn-primary" onclick="runAllTests()">Run All Tests</button>
            <div id="tests" style="margin-top:16px"></div>
        </div>
        <div class="card">
            <h2>Vehicle Data from MongoDB</h2>
            <button class="btn btn-primary" onclick="loadVehicles()">Fetch Vehicles</button>
            <div id="vehicles"></div>
        </div>
        <div class="card">
            <h2>Raw API Response</h2>
            <pre id="raw">Click a button above to see data...</pre>
        </div>
    </div>
    <script>
    async function testURL(url){
        try{const r=await fetch(url);const d=await r.json();return{ok:true,data:d}}
        catch(e){return{ok:false,error:e.message}}
    }
    async function runAllTests(){
        const el=document.getElementById('tests');
        el.innerHTML='<p class="status loading">Testing...</p>';
        const tests=[
            {name:'Backend API',url:'/api/health'},
            {name:'FastAPI',url:'/py/health'},
            {name:'MongoDB (via API)',url:'/api/vehicles'},
            {name:'Static Files (Nginx)',url:'/static/sample-vehicles.json'}
        ];
        let html='';
        for(const t of tests){
            const r=await testURL(t.url);
            const cls=r.ok?'pass':'fail';
            const txt=r.ok?'✓ Connected':'✗ Failed';
            html+='<div class="test-row"><span>'+t.name+'</span><span class="status '+cls+'">'+txt+'</span></div>';
        }
        el.innerHTML=html;
    }
    async function loadVehicles(){
        const r=await testURL('/api/vehicles');
        const el=document.getElementById('vehicles');
        document.getElementById('raw').textContent=JSON.stringify(r.data,null,2);
        if(r.ok&&r.data.length){
            let h='<table><thead><tr><th>ID</th><th>Plate</th><th>Make</th><th>Model</th><th>Year</th><th>Status</th></tr></thead><tbody>';
            r.data.forEach(v=>{
                const c=v.status==='active'?'pass':'fail';
                h+='<tr><td>'+v.vehicleId+'</td><td>'+v.plateNumber+'</td><td>'+v.make+'</td><td>'+v.model+'</td><td>'+v.year+'</td><td><span class="status '+c+'">'+v.status+'</span></td></tr>';
            });
            h+='</tbody></table>';
            el.innerHTML=h;
        }else{el.innerHTML='<p>No data. Run: bash scripts/load-test-data.sh</p>'}
    }
    </script>
</body>
</html>
FEHTML

#=============================================
# STEP 6: Create FastAPI
#=============================================
cat > fastapi/requirements.txt << 'PYREQ'
fastapi==0.104.0
uvicorn[standard]==0.24.0
pymongo==4.6.0
pydantic==2.5.0
PYREQ

cat > fastapi/main.py << 'PYAPP'
from fastapi import FastAPI
from pymongo import MongoClient
from datetime import datetime
import os

app = FastAPI(title="AVMS FastAPI")
MONGO_URL = os.getenv("MONGODB_URL", "mongodb://admin:avms_admin_pass_2024@mongodb:27017/avms?authSource=admin")

def get_db():
    try:
        client = MongoClient(MONGO_URL, serverSelectionTimeoutMS=5000)
        client.server_info()
        return client.avms
    except:
        return None

@app.get("/health")
def health():
    db = get_db()
    return {"status":"healthy","service":"fastapi","database":"connected" if db else "disconnected","timestamp":datetime.now().isoformat()}

@app.get("/vehicles")
def vehicles():
    db = get_db()
    if not db: return {"error":"DB not connected"}
    return list(db.vehicles.find({},{"_id":0}))

@app.get("/stats")
def stats():
    db = get_db()
    if not db: return {"error":"DB not connected"}
    return {
        "total_vehicles":db.vehicles.count_documents({}),
        "active":db.vehicles.count_documents({"status":"active"}),
        "maintenance":db.vehicles.count_documents({"status":"maintenance"}),
        "users":db.users.count_documents({}),
        "records":db.maintenance_records.count_documents({})
    }
PYAPP

echo -e "${GREEN}✓ Application files created${NC}"

#=============================================
# STEP 7: Create test data and scripts
#=============================================
echo ""
echo -e "${YELLOW}[4/8] Creating test data...${NC}"

cd "$WORK_DIR/test-data"

cat > init-mongo.js << 'MONGOINIT'
print("=== AVMS Test Data Loader ===");
db = db.getSiblingDB('avms');

db.users.drop();
db.vehicles.drop();
db.maintenance_records.drop();

print("Inserting users...");
db.users.insertMany([
    {username:"admin",email:"admin@avms.local",password:"$2b$10$hash",role:"administrator",firstName:"System",lastName:"Administrator",isActive:true,createdAt:new Date("2024-01-01"),updatedAt:new Date()},
    {username:"manager",email:"manager@avms.local",password:"$2b$10$hash",role:"manager",firstName:"Fleet",lastName:"Manager",isActive:true,createdAt:new Date("2024-01-10"),updatedAt:new Date()},
    {username:"testuser",email:"testuser@avms.local",password:"$2b$10$hash",role:"user",firstName:"Test",lastName:"User",isActive:true,createdAt:new Date("2024-01-15"),updatedAt:new Date()}
]);
print("  Users: " + db.users.countDocuments());

print("Inserting vehicles...");
db.vehicles.insertMany([
    {vehicleId:"VH-001",plateNumber:"ABC-1234",make:"Toyota",model:"Camry",year:2022,color:"White",status:"active",fuelType:"Petrol",mileage:15000,lastServiceDate:new Date("2024-06-15"),createdAt:new Date(),updatedAt:new Date()},
    {vehicleId:"VH-002",plateNumber:"XYZ-5678",make:"Honda",model:"Civic",year:2023,color:"Silver",status:"active",fuelType:"Petrol",mileage:8500,lastServiceDate:new Date("2024-08-20"),createdAt:new Date(),updatedAt:new Date()},
    {vehicleId:"VH-003",plateNumber:"DEF-9012",make:"Ford",model:"Transit",year:2021,color:"Blue",status:"maintenance",fuelType:"Diesel",mileage:45000,lastServiceDate:new Date("2024-09-01"),createdAt:new Date(),updatedAt:new Date()},
    {vehicleId:"VH-004",plateNumber:"GHI-3456",make:"Chevrolet",model:"Silverado",year:2020,color:"Black",status:"active",fuelType:"Diesel",mileage:62000,lastServiceDate:new Date("2024-07-10"),createdAt:new Date(),updatedAt:new Date()},
    {vehicleId:"VH-005",plateNumber:"JKL-7890",make:"Tesla",model:"Model 3",year:2024,color:"Red",status:"active",fuelType:"Electric",mileage:2500,lastServiceDate:new Date("2024-09-15"),createdAt:new Date(),updatedAt:new Date()}
]);
print("  Vehicles: " + db.vehicles.countDocuments());

print("Inserting maintenance records...");
db.maintenance_records.insertMany([
    {recordId:"MR-001",vehicleId:"VH-001",type:"Oil Change",description:"Regular oil change",cost:150,date:new Date("2024-06-15"),mileageAtService:15000,createdAt:new Date()},
    {recordId:"MR-002",vehicleId:"VH-002",type:"Tire Rotation",description:"Rotated all tires",cost:50,date:new Date("2024-08-20"),mileageAtService:8500,createdAt:new Date()},
    {recordId:"MR-003",vehicleId:"VH-003",type:"Brake Service",description:"Replaced front brake pads",cost:450,date:new Date("2024-09-01"),mileageAtService:45000,createdAt:new Date()}
]);
print("  Records: " + db.maintenance_records.countDocuments());

print("Creating indexes...");
db.users.createIndex({username:1},{unique:true});
db.users.createIndex({email:1},{unique:true});
db.vehicles.createIndex({vehicleId:1},{unique:true});
db.vehicles.createIndex({plateNumber:1},{unique:true});
db.vehicles.createIndex({status:1});
db.maintenance_records.createIndex({vehicleId:1});

print("\n=== Done! ===");
MONGOINIT

cat > sample-files/sample-vehicles.json << 'SJSON'
{
    "source": "static-file-served-by-nginx",
    "description": "This file is served directly from Nginx",
    "vehicles": [
        {"id": "STATIC-001", "name": "Static Test Vehicle 1"},
        {"id": "STATIC-002", "name": "Static Test Vehicle 2"}
    ]
}
SJSON

# Copy test data into avms-source
cp -r "$WORK_DIR/test-data" "$WORK_DIR/avms-source/"

echo -e "${GREEN}✓ Test data created${NC}"

#=============================================
# STEP 8: Create installation scripts
#=============================================
echo ""
echo -e "${YELLOW}[5/8] Creating installation scripts...${NC}"

cd "$WORK_DIR/scripts"

# --- check-prerequisites.sh ---
cat > check-prerequisites.sh << 'CPSCRIPT'
#!/bin/bash
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'
PASS=0; FAIL=0; WARN=0
ok()  { echo -e "  [${GREEN}✓ PASS${NC}] $1"; ((PASS++)); }
nok() { echo -e "  [${RED}✗ FAIL${NC}] $1"; ((FAIL++)); }
wrn() { echo -e "  [${YELLOW}! WARN${NC}] $1"; ((WARN++)); }
inf() { echo -e "  [${BLUE}i INFO${NC}] $1"; }

echo ""
echo -e "${BLUE}══════════════════════════════════════${NC}"
echo -e "${BLUE}  AVMS Prerequisites Check${NC}"
echo -e "${BLUE}══════════════════════════════════════${NC}"

echo -e "\n${YELLOW}--- OS ---${NC}"
if [ -f /etc/os-release ]; then
    . /etc/os-release; inf "OS: $NAME $VERSION_ID"
    [[ "$ID" == "ubuntu" ]] && ok "Ubuntu detected" || wrn "Non-Ubuntu OS"
else nok "Cannot detect OS"; fi
ARCH=$(uname -m)
[[ "$ARCH" == "x86_64" ]] && ok "Arch: $ARCH" || wrn "Arch: $ARCH"

echo -e "\n${YELLOW}--- Hardware ---${NC}"
RAM=$(($(grep MemTotal /proc/meminfo | awk '{print $2}') / 1024))
[ "$RAM" -ge 4096 ] && ok "RAM: ${RAM}MB" || nok "RAM: ${RAM}MB (need 4096MB)"
CPU=$(nproc)
[ "$CPU" -ge 2 ] && ok "CPU: $CPU cores" || wrn "CPU: $CPU cores"
DISK=$(df / | tail -1 | awk '{print int($4/1024/1024)}')
[ "$DISK" -ge 20 ] && ok "Disk: ${DISK}GB free" || nok "Disk: ${DISK}GB (need 20GB)"

echo -e "\n${YELLOW}--- Permissions ---${NC}"
sudo -n true 2>/dev/null && ok "Sudo: available" || nok "Sudo: not available"

echo -e "\n${YELLOW}--- Ports ---${NC}"
for P in 8088 3000 4201 8000 27017; do
    ss -tuln 2>/dev/null | grep -q ":$P " && nok "Port $P in use" || ok "Port $P available"
done

echo -e "\n${YELLOW}--- Software ---${NC}"
command -v docker &>/dev/null && wrn "Docker installed: $(docker --version 2>/dev/null)" || ok "Docker not installed"
for S in mongodb mongod nginx apache2; do
    systemctl is-active --quiet "$S" 2>/dev/null && wrn "$S is running"
done

echo -e "\n${YELLOW}--- Tools ---${NC}"
for T in tar gzip bash grep awk sed; do
    command -v "$T" &>/dev/null && ok "$T" || nok "$T missing"
done

echo -e "\n${YELLOW}--- Package ---${NC}"
BD="$(dirname "$(readlink -f "$0")")/.."
for D in docker-debs docker-images avms-source scripts test-data; do
    [ -d "$BD/$D" ] && ok "$D/ found" || nok "$D/ MISSING"
done
DC=$(find "$BD/docker-debs" -name "*.deb" 2>/dev/null | wc -l)
[ "$DC" -gt 0 ] && ok "$DC .deb files" || nok "No .deb files"
IC=$(find "$BD/docker-images" -name "*.tar*" 2>/dev/null | wc -l)
[ "$IC" -gt 0 ] && ok "$IC image files" || nok "No image files"
[ -f "$BD/avms-source/docker-compose.yml" ] && ok "docker-compose.yml" || nok "docker-compose.yml MISSING"

echo ""
echo -e "${BLUE}══════════════════════════════════════${NC}"
echo -e "  ${GREEN}Pass:${NC} $PASS  ${YELLOW}Warn:${NC} $WARN  ${RED}Fail:${NC} $FAIL"
[ "$FAIL" -eq 0 ] && echo -e "  ${GREEN}✓ READY to install${NC}" || echo -e "  ${RED}✗ Fix failures first${NC}"
echo ""
[ "$FAIL" -eq 0 ] && exit 0 || exit 1
CPSCRIPT

# --- install.sh ---
cat > install.sh << 'INSCRIPT'
#!/bin/bash
set -e
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'

SD=$(dirname "$(readlink -f "$0")")
BD="$SD/.."
TARGET="/opt/avms"

echo -e "${BLUE}╔═══════════════════════════════════════╗${NC}"
echo -e "${BLUE}║    AVMS OFFLINE INSTALLER             ║${NC}"
echo -e "${BLUE}╚═══════════════════════════════════════╝${NC}"
echo ""

echo -e "${YELLOW}[1/6] Prerequisites...${NC}"
bash "$SD/check-prerequisites.sh" || {
    read -p "Continue anyway? [y/N]: " C; [[ ! "$C" =~ ^[Yy]$ ]] && exit 1
}

echo -e "\n${YELLOW}[2/6] Installing Docker...${NC}"
if command -v docker &>/dev/null && docker info &>/dev/null; then
    echo "Docker already installed, skipping..."
else
    cd "$BD/docker-debs"
    sudo dpkg -i *.deb 2>/dev/null || true
    sudo apt-get install -f -y --no-download 2>/dev/null || true
    sudo dpkg -i *.deb || { echo -e "${RED}Docker install failed!${NC}"; exit 1; }
    sudo systemctl enable docker && sudo systemctl start docker
    sudo usermod -aG docker "$USER"
    echo "Waiting for Docker..."; sleep 10
fi
echo -e "${GREEN}✓ Docker ready${NC}"

echo -e "\n${YELLOW}[3/6] Loading images...${NC}"
cd "$BD/docker-images"
for F in *.tar.gz; do [ -f "$F" ] && echo "  $F..." && gunzip -c "$F" | sudo docker load; done
for F in *.tar; do [ -f "$F" ] && echo "  $F..." && sudo docker load -i "$F"; done
echo -e "${GREEN}✓ Images loaded${NC}"
sudo docker images --format "  {{.Repository}}:{{.Tag}} ({{.Size}})"

echo -e "\n${YELLOW}[4/6] Deploying...${NC}"
sudo mkdir -p "$TARGET"
sudo cp -r "$BD/avms-source/"* "$TARGET/"
sudo cp -r "$BD/test-data" "$TARGET/"
sudo cp -r "$BD/scripts" "$TARGET/"
sudo chown -R "$USER:$USER" "$TARGET"
cd "$TARGET"
sudo docker compose up -d
echo -e "${GREEN}✓ Deployed${NC}"

echo -e "\n${YELLOW}[5/6] Firewall...${NC}"
if command -v ufw &>/dev/null; then
    sudo ufw allow 8088/tcp comment "AVMS" 2>/dev/null || true
    echo -e "${GREEN}✓ Port 8088 allowed${NC}"
fi

echo -e "\n${YELLOW}[6/6] Waiting for services...${NC}"
sleep 30
sudo docker compose ps

IP=$(hostname -I 2>/dev/null | awk '{print $1}')
echo ""
echo -e "${GREEN}╔════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║       INSTALLATION COMPLETE!                   ║${NC}"
echo -e "${GREEN}╚════════════════════════════════════════════════╝${NC}"
echo ""
echo "  Access: http://${IP}:8088"
echo ""
echo "  Next:"
echo "    cd $TARGET"
echo "    bash scripts/load-test-data.sh"
echo "    bash scripts/verify-installation.sh"
echo ""
INSCRIPT

# --- load-test-data.sh ---
cat > load-test-data.sh << 'LDSCRIPT'
#!/bin/bash
set -e
RED='\033[0;31m'; GREEN='\033[0;32m'; BLUE='\033[0;34m'; NC='\033[0m'

SD=$(dirname "$(readlink -f "$0")")
AD="$SD/.."
cd "$AD"

echo -e "${BLUE}Loading AVMS test data...${NC}"

MONGO=$(docker compose ps -q mongodb 2>/dev/null)
if [ -z "$MONGO" ]; then
    echo "Starting MongoDB..."; docker compose up -d mongodb; sleep 10
    MONGO=$(docker compose ps -q mongodb 2>/dev/null)
fi
[ -z "$MONGO" ] && echo -e "${RED}MongoDB not found!${NC}" && exit 1

docker cp "$AD/test-data/init-mongo.js" "$MONGO:/tmp/init-mongo.js"
docker exec -i "$MONGO" mongosh --quiet /tmp/init-mongo.js

VC=$(docker exec "$MONGO" mongosh --quiet --eval "db.getSiblingDB('avms').vehicles.countDocuments()")
UC=$(docker exec "$MONGO" mongosh --quiet --eval "db.getSiblingDB('avms').users.countDocuments()")

echo ""
echo -e "${GREEN}✓ Loaded: $VC vehicles, $UC users${NC}"
echo ""
echo "Test endpoints:"
echo "  curl http://localhost:8088/api/vehicles"
echo "  curl http://localhost:8088/api/health"
echo "  curl http://localhost:8088/py/health"
echo "  curl http://localhost:8088/py/stats"
echo "  curl http://localhost:8088/static/sample-vehicles.json"
echo ""
echo "  Browser: http://$(hostname -I 2>/dev/null | awk '{print $1}'):8088"
LDSCRIPT

# --- verify-installation.sh ---
cat > verify-installation.sh << 'VSCRIPT'
#!/bin/bash
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'
PASS=0; FAIL=0
ok()  { echo -e "  [${GREEN}✓${NC}] $1"; ((PASS++)); }
nok() { echo -e "  [${RED}✗${NC}] $1"; ((FAIL++)); }

SD=$(dirname "$(readlink -f "$0")")
cd "$SD/.."

echo -e "\n${BLUE}AVMS Installation Verification${NC}\n"

echo -e "${YELLOW}[Containers]${NC}"
for S in frontend backend fastapi mongodb caddy; do
    docker compose ps "$S" 2>/dev/null | grep -qi "running\|up" && ok "$S running" || nok "$S NOT running"
done

echo -e "\n${YELLOW}[Endpoints]${NC}"
for URL in "http://localhost:8088|Frontend" "http://localhost:8088/api/health|Backend API" "http://localhost:8088/py/health|FastAPI" "http://localhost:8088/static/sample-vehicles.json|Static files"; do
    U="${URL%%|*}"; N="${URL##*|}"
    C=$(curl -s -o /dev/null -w "%{http_code}" "$U" 2>/dev/null)
    [[ "$C" =~ ^(200|301|302)$ ]] && ok "$N → HTTP $C" || nok "$N → HTTP $C"
done

echo -e "\n${YELLOW}[Database]${NC}"
M=$(docker compose ps -q mongodb 2>/dev/null)
if [ -n "$M" ]; then
    VC=$(docker exec "$M" mongosh --quiet --eval "db.getSiblingDB('avms').vehicles.countDocuments()" 2>/dev/null || echo "0")
    [ "$VC" -gt 0 ] && ok "MongoDB: $VC vehicles" || nok "No data - run load-test-data.sh"
fi

echo -e "\n${YELLOW}[Full Data Flow]${NC}"
D=$(curl -s http://localhost:8088/api/vehicles 2>/dev/null)
if echo "$D" | grep -q "vehicleId"; then
    FC=$(echo "$D" | grep -o "vehicleId" | wc -l)
    ok "MongoDB → Backend → Caddy → Browser ($FC vehicles)"
else
    nok "Data flow failed"
fi

echo -e "\n  ${GREEN}Pass:${NC} $PASS  ${RED}Fail:${NC} $FAIL"
[ "$FAIL" -eq 0 ] && echo -e "\n  ${GREEN}✓ AVMS fully operational!${NC}" || echo -e "\n  ${RED}✗ Issues found. Run: docker compose logs -f${NC}"
echo ""
VSCRIPT

chmod +x *.sh
echo -e "${GREEN}✓ All scripts created${NC}"

#=============================================
# STEP 9: Documentation
#=============================================
echo ""
echo -e "${YELLOW}[6/8] Creating documentation...${NC}"

cd "$WORK_DIR"

cat > README.txt << RDEOF
==========================================
AVMS OFFLINE INSTALLATION PACKAGE
==========================================
Built: $(date)
Target: Ubuntu 22.04 LTS (amd64)

QUICK INSTALL:
  1. sudo mount /dev/sr0 /mnt
  2. cp -r /mnt/* /opt/avms-install/
  3. cd /opt/avms-install
  4. bash scripts/check-prerequisites.sh
  5. bash scripts/install.sh
  6. bash scripts/load-test-data.sh
  7. bash scripts/verify-installation.sh
  8. Open http://SERVER-IP:8088
==========================================
RDEOF

echo -e "${GREEN}✓ Documentation created${NC}"

#=============================================
# STEP 10: Checksums + ISO
#=============================================
echo ""
echo -e "${YELLOW}[7/8] Creating checksums...${NC}"

cd "$WORK_DIR"
find . -type f ! -name "CHECKSUMS.md5" ! -name "*.log" ! -name "_*" -exec md5 -r {} \; > CHECKSUMS.md5 2>/dev/null || \
find . -type f ! -name "CHECKSUMS.md5" ! -name "*.log" ! -name "_*" -exec md5sum {} \; > CHECKSUMS.md5 2>/dev/null

echo -e "${GREEN}✓ Checksums created${NC}"

echo ""
echo -e "${YELLOW}[8/8] Creating ISO...${NC}"
echo ""
echo -e "${BLUE}Package Summary:${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Docker .deb packages: $(find docker-debs -name '*.deb' 2>/dev/null | wc -l | tr -d ' ') files"
echo "Docker images:        $(find docker-images -name '*.tar.gz' 2>/dev/null | wc -l | tr -d ' ') files"
echo "Scripts:              $(find scripts -name '*.sh' 2>/dev/null | wc -l | tr -d ' ') files"
echo ""
du -sh docker-debs/ docker-images/ avms-source/ scripts/ test-data/ 2>/dev/null
echo ""
echo "Total: $(du -sh . | awk '{print $1}')"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

ISO_FILE="$HOME/Desktop/avms-offline-installer-$(date +%Y%m%d).iso"

hdiutil makehybrid \
    -o "$ISO_FILE" \
    -iso \
    -joliet \
    -default-volume-name "AVMS_INSTALLER" \
    "$WORK_DIR" 2>/dev/null

if [ -f "$ISO_FILE" ]; then
    ISO_SIZE=$(ls -lh "$ISO_FILE" | awk '{print $5}')
    echo ""
    echo -e "${GREEN}╔═══════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║          BUILD COMPLETE!                          ║${NC}"
    echo -e "${GREEN}╚═══════════════════════════════════════════════════╝${NC}"
    echo ""
    echo "  ISO: $ISO_FILE"
    echo "  Size: $ISO_SIZE"
    echo ""
    echo "  Burn DVD on Mac:"
    echo "    Right-click ISO → Burn to Disc"
    echo "    OR: hdiutil burn '$ISO_FILE'"
    echo ""
    echo "  On Ubuntu server:"
    echo "    sudo mount /dev/sr0 /mnt"
    echo "    cp -r /mnt/* /opt/avms-install/"
    echo "    cd /opt/avms-install"
    echo "    bash scripts/install.sh"
    echo ""
else
    echo -e "${RED}✗ ISO creation failed${NC}"
    echo "Folder available at: $WORK_DIR"
fi
MAINSCRIPT

chmod +x build-offline-package-mac.sh
