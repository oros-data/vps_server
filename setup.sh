#!/bin/bash

# Setup script for GTM Server with NGINX
echo "Setting up GTM Server with NGINX..."

# Create required directories
mkdir -p nginx/conf.d nginx/ssl nginx/cache nginx/auth grafana/provisioning/datasources grafana/provisioning/dashboards prometheus

# Check if Docker is installed
if ! command -v docker &> /dev/null; then
    echo "Docker is not installed. Installing Docker..."
    curl -fsSL https://get.docker.com -o get-docker.sh
    sudo sh get-docker.sh
    sudo usermod -aG docker $USER
    echo "Docker installed. Please log out and back in for group changes to take effect."
fi

# Check if Docker Compose is installed
if ! command -v docker-compose &> /dev/null; then
    echo "Docker Compose is not installed. Installing Docker Compose..."
    sudo curl -L "https://github.com/docker/compose/releases/download/1.29.2/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    sudo chmod +x /usr/local/bin/docker-compose
    echo "Docker Compose installed."
fi

# Ask for domain name
read -p "Enter your domain name [datalakeops.com]: " domain_name
domain_name=${domain_name:-datalakeops.com}

# Ask for GTM container configuration
read -p "Enter your GTM container configuration ID: " container_config

# Update domain name in NGINX configuration
sed -i "s/datalakeops.com/$domain_name/g" nginx/conf.d/default.conf

# Update GTM container configuration in docker-compose.yml
sed -i "s/your_container_config/$container_config/g" docker-compose.yml

# Ask for SSL certificate method
echo "How would you like to configure SSL?"
echo "1) Use Cloudflare Origin Certificates (recommended)"
echo "2) Use Let's Encrypt"
read -p "Enter your choice [1]: " ssl_choice
ssl_choice=${ssl_choice:-1}

if [ "$ssl_choice" == "1" ]; then
    echo "Please obtain a certificate from Cloudflare and place it in nginx/ssl/$domain_name.crt"
    echo "Please obtain a private key from Cloudflare and place it in nginx/ssl/$domain_name.key"
    read -p "Press Enter when you have completed this step..." dummy
elif [ "$ssl_choice" == "2" ]; then
    if ! command -v certbot &> /dev/null; then
        echo "Installing certbot..."
        sudo apt-get update
        sudo apt-get install -y certbot
    fi
    echo "Obtaining certificates from Let's Encrypt..."
    sudo certbot certonly --standalone -d $domain_name -d www.$domain_name
    echo "Copying certificates to nginx/ssl..."
    sudo cp /etc/letsencrypt/live/$domain_name/fullchain.pem nginx/ssl/$domain_name.crt
    sudo cp /etc/letsencrypt/live/$domain_name/privkey.pem nginx/ssl/$domain_name.key
fi

# Create basic auth for prometheus
echo "Creating basic auth for Prometheus..."
if command -v htpasswd &> /dev/null; then
    htpasswd -bc nginx/auth/.htpasswd admin admin
else
    echo "Apache utils not installed. Installing..."
    sudo apt-get update
    sudo apt-get install -y apache2-utils
    htpasswd -bc nginx/auth/.htpasswd admin admin
fi

# Change Grafana password
read -p "Enter a secure password for Grafana admin [!DataLake123*]: " grafana_password
grafana_password=${grafana_password:-!DataLake123*}
sed -i "s/!DataLake123*/$grafana_password/g" docker-compose.yml

echo "Setup completed! You can now start the stack with:"
echo "docker-compose up -d" 