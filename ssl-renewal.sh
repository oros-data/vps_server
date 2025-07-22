#!/bin/bash

# SSL Certificate Renewal Script for GTM Server Clients
# This script automates certificate management for client domains

CLIENTS_DIR="nginx/conf.d/clients"
SSL_DIR="nginx/ssl/client-domains"

# Ensure certbot is installed
if ! command -v certbot &> /dev/null; then
    echo "Installing certbot..."
    sudo apt-get update
    sudo apt-get install -y certbot
fi

# Extract all client domains from the config files
get_domains() {
    grep -h "server_name" ${CLIENTS_DIR}/*.conf | awk '{print $2}' | sed 's/;//'
}

# Renew certificates for all domains
renew_certs() {
    echo "Stopping NGINX for certificate renewal..."
    sudo docker-compose stop nginx
    
    # Get all domains
    DOMAINS=$(get_domains)
    
    for DOMAIN in $DOMAINS; do
        echo "Processing domain: $DOMAIN"
        
        # Check if we should renew
        if [ -f "${SSL_DIR}/${DOMAIN}.crt" ]; then
            EXPIRY=$(openssl x509 -enddate -noout -in "${SSL_DIR}/${DOMAIN}.crt" | cut -d= -f2)
            EXPIRY_DATE=$(date -d "${EXPIRY}" +%s)
            NOW=$(date +%s)
            DAYS_LEFT=$(( (EXPIRY_DATE - NOW) / 86400 ))
            
            if [ $DAYS_LEFT -gt 30 ]; then
                echo "Certificate for $DOMAIN still valid for $DAYS_LEFT days. Skipping."
                continue
            fi
        fi
        
        echo "Obtaining certificate for $DOMAIN..."
        
        # Try to obtain a certificate
        sudo certbot certonly --standalone --non-interactive --agree-tos \
            --email admin@datalakeops.com \
            -d $DOMAIN
            
        # If successful, copy the certificate
        if [ $? -eq 0 ]; then
            echo "Certificate obtained, installing..."
            sudo cp /etc/letsencrypt/live/${DOMAIN}/fullchain.pem "${SSL_DIR}/${DOMAIN}.crt"
            sudo cp /etc/letsencrypt/live/${DOMAIN}/privkey.pem "${SSL_DIR}/${DOMAIN}.key"
            sudo chown $(whoami) "${SSL_DIR}/${DOMAIN}.crt" "${SSL_DIR}/${DOMAIN}.key"
        else
            echo "Failed to obtain certificate for $DOMAIN"
        fi
    done
    
    echo "Starting NGINX..."
    sudo docker-compose start nginx
}

# Main script execution
echo "Starting SSL certificate renewal process..."
renew_certs
echo "SSL certificate renewal completed!"

# Create a cron job to run this script weekly if it doesn't exist
CRON_JOB="0 0 * * 0 $(pwd)/ssl-renewal.sh >> $(pwd)/ssl-renewal.log 2>&1"
if ! (crontab -l | grep -q "ssl-renewal.sh"); then
    (crontab -l 2>/dev/null; echo "$CRON_JOB") | crontab -
    echo "Cron job added for weekly certificate renewal"
fi 