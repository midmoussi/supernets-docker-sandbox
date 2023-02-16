#!/bin/bash

# Set variables
RELEASE_TAG="v0.6.3"
DOMAIN="www.example-rpc.com"
RPC_PORT="10002"
WS_PORT="10002"

# Logging function
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

# Exit script on error
set -e

# Logging on to server
log "Logging on to server"
ssh -i <your_server_key.pem> ubuntu@ec2-<ip>.compute-<X>.amazonaws.com

# Install Docker
log "Installing Docker"
sudo apt-get update
sudo apt-get install -y docker.io
sudo usermod -aG docker $USER
newgrp docker

# Install Docker Compose
log "Installing Docker Compose"
sudo apt install -y python3-pip
sudo pip3 install docker-compose

# Clone Edge and switch to the desired release commit
log "Cloning Polygon Edge"
git clone https://github.com/0xPolygon/polygon-edge.git
cd polygon-edge
git checkout -b $RELEASE_TAG

# Build and run containers
log "Building and running containers"
cd docker/local/
sudo docker-compose build
sudo docker-compose up -d

# Setting up nginx and certbot
# Install Nginx
log "Installing Nginx"
sudo apt-get update
sudo apt-get install -y nginx

# Install Certbot
log "Installing Certbot"
sudo apt-get install -y certbot python3-certbot-nginx

# Creating nginx config
log "Creating Nginx config"
cd /etc/nginx/sites-enabled/
echo "server {
    server_name $DOMAIN;
    location / {
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_pass http://127.0.0.1:$RPC_PORT;

        # WebSocket support
    	proxy_http_version 1.1;
    	proxy_set_header Upgrade \$http_upgrade;
    	proxy_set_header Connection \"upgrade\";
    }
}" | sudo tee $DOMAIN.conf > /dev/null

# Verify Nginx config and restart Nginx
log "Reloading Nginx config"
sudo nginx -t && sudo nginx -s reload

# Obtain SSL/TLS Certificate
log "Obtaining SSL/TLS Certificate"
sudo certbot --nginx -d $DOMAIN -d www.$DOMAIN

# Done
log "Setup complete"
