#!/bin/bash
set -e
# Log all output to help with debugging if something fails
exec > >(tee /var/log/user-data.log|logger -t user-data -s 2>/dev/console) 2>&1

echo "Updating system..."
apt-get update -y
apt-get upgrade -y

# 1. Install Docker
echo "Installing Docker..."
apt-get install -y ca-certificates curl gnupg lsb-release
curl -fsSL https://get.docker.com -o get-docker.sh
sh get-docker.sh
usermod -aG docker ubuntu

# 2. Install Nginx
echo "Installing Nginx..."
apt-get install -y nginx
systemctl enable nginx
systemctl start nginx

# 3. Install MicroK8s
echo "Installing MicroK8s..."
snap wait system seed.loaded
snap install microk8s --classic --channel=1.28/stable
usermod -a -G microk8s ubuntu
mkdir -p /home/ubuntu/.kube
chown -f -R ubuntu /home/ubuntu/.kube

# Wait for MicroK8s to be ready before enabling addons
echo "Waiting for MicroK8s to initialize..."
microk8s status --wait-ready

# Enable essential MicroK8s add-ons
# Note: We enable 'dns' for internal service discovery. 
# We don't enable 'ingress' here because it might conflict with host Nginx on Port 80.
microk8s enable dns

# 4. Create a basic Nginx Reverse Proxy Config
echo "Configuring Nginx..."
cat <<EOF > /etc/nginx/sites-available/reverse-proxy
# Port 80 -> Kubernetes (Assumes App is on NodePort 30001)
server {
    listen 80;
    location / {
        proxy_pass http://127.0.0.1:30001;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
    }
}

# Port 8080 -> Docker (Assumes Container is on Port 8000)
server {
    listen 8080;
    location / {
        proxy_pass http://127.0.0.1:4000;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
    }
}
EOF

ln -sf /etc/nginx/sites-available/reverse-proxy /etc/nginx/sites-enabled/reverse-proxy
rm /etc/nginx/sites-enabled/default
systemctl restart nginx

echo "Setup Complete!"