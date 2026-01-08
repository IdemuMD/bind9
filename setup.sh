#!/bin/bash

# JWT Authentication API - Setup Script for Proxmox VM (Ubuntu)
# This script sets up the complete JWT authentication system

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}  JWT Authentication API - Setup${NC}"
echo -e "${BLUE}  For Proxmox VM (Ubuntu)${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# Variables
PROJECT_DIR="/opt/jwt-auth-api"
NODE_VERSION="20"

# Check if running as root
if [ "$EUID" -ne 0 ]; then 
    echo -e "${RED}Please run as root (use sudo)${NC}"
    exit 1
fi

echo -e "${YELLOW}Step 1: Updating system...${NC}"
apt-get update && apt-get upgrade -y

echo -e "${YELLOW}Step 2: Installing Node.js...${NC}"
# Install curl if not present
apt-get install -y curl

# Install Node.js using NodeSource repository
curl -fsSL https://deb.nodesource.com/setup_${NODE_VERSION}.x | bash -
apt-get install -y nodejs

# Verify installation
node --version
npm --version

echo -e "${YELLOW}Step 3: Creating project directory...${NC}"
mkdir -p $PROJECT_DIR/backend
mkdir -p $PROJECT_DIR/frontend

echo -e "${YELLOW}Step 4: Copying project files...${NC}"
# Copy backend files
cp backend/package.json $PROJECT_DIR/backend/
cp backend/server.js $PROJECT_DIR/backend/
cp backend/users.json $PROJECT_DIR/backend/ 2>/dev/null || echo "No users.json to copy"

# Copy frontend files
cp frontend/index.html $PROJECT_DIR/frontend/

echo -e "${YELLOW}Step 5: Installing dependencies...${NC}"
cd $PROJECT_DIR/backend
npm install

echo -e "${YELLOW}Step 6: Setting up environment variables...${NC}"
# Create environment file
cat > $PROJECT_DIR/backend/.env << EOF
# JWT Authentication API Environment Configuration
# IMPORTANT: Change these values in production!

# Secret key for JWT signing (USE A STRONG RANDOM KEY IN PRODUCTION!)
JWT_SECRET=$(openssl rand -hex 64)

# Server port
PORT=3000

# Token expiry time (e.g., 1h, 24h, 7d)
TOKEN_EXPIRY=1h
EOF

echo -e "${YELLOW}Step 7: Creating systemd service...${NC}"
# Create systemd service file
cat > /etc/systemd/system/jwt-auth-api.service << EOF
[Unit]
Description=JWT Authentication API
Documentation=https://github.com/yourusername/jwt-auth-api
After=network.target

[Service]
Type=simple
User=www-data
Group=www-data
WorkingDirectory=$PROJECT_DIR/backend
ExecStart=/usr/bin/node server.js
Restart=on-failure
RestartSec=5
Environment=NODE_ENV=production
EnvironmentFile=$PROJECT_DIR/backend/.env

# Security hardening
NoNewPrivileges=true
ProtectSystem=strict
ProtectHome=true
PrivateTmp=true
ReadWritePaths=$PROJECT_DIR/backend

[Install]
WantedBy=multi-user.target
EOF

echo -e "${YELLOW}Step 8: Configuring firewall...${NC}"
# Install UFW if not present
apt-get install -y ufw

# Allow SSH
ufw allow ssh

# Allow HTTP and HTTPS
ufw allow 3000/tcp

# Enable firewall
echo "y" | ufw enable

echo -e "${YELLOW}Step 9: Setting up firewall rules for production...${NC}"
echo "For production, consider using nginx as a reverse proxy:"
echo "  - Install nginx: apt-get install -y nginx"
echo "  - Configure SSL/TLS with Let's Encrypt"
echo "  - Update UFW: ufw allow 'Nginx Full'"

echo -e "${YELLOW}Step 10: Starting the service...${NC}"
# Reload systemd
systemctl daemon-reload

# Enable and start the service
systemctl enable jwt-auth-api
systemctl start jwt-auth-api

# Check status
systemctl status jwt-auth-api

echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}  Setup Complete!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo -e "API Server: http://YOUR_VM_IP:3000"
echo -e "Health Check: http://YOUR_VM_IP:3000/health"
echo -e "API Docs: http://YOUR_VM_IP:3000/"
echo ""
echo -e "${YELLOW}Test Users:${NC}"
echo -e "  Username: testuser | Password: test123 | Role: user"
echo -e "  Username: admin    | Password: admin123 | Role: admin"
echo ""
echo -e "${YELLOW}Useful Commands:${NC}"
echo -e "  View logs:     journalctl -u jwt-auth-api -f"
echo -e "  Stop service:  systemctl stop jwt-auth-api"
echo -e "  Restart:       systemctl restart jwt-auth-api"
echo -e "  Check status:  systemctl status jwt-auth-api"
echo ""
echo -e "${YELLOW}Configuration File:${NC}"
echo -e "  $PROJECT_DIR/backend/.env"
echo ""

