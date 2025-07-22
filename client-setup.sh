#!/bin/bash

# Client Management Script for GTM Server
# Usage: ./client-setup.sh add domain.com
# Usage: ./client-setup.sh remove domain.com

ACTION=$1
DOMAIN=$2
SUBDOMAIN=${3:-gtm}
FULL_DOMAIN="${SUBDOMAIN}.${DOMAIN}"
NGINX_CONF="nginx/conf.d/clients"
SSL_DIR="nginx/ssl/client-domains"

# Ensure directories exist
mkdir -p $NGINX_CONF
mkdir -p $SSL_DIR

# Function to validate domain
validate_domain() {
    if [[ ! $DOMAIN =~ ^[a-zA-Z0-9][a-zA-Z0-9-]{1,61}[a-zA-Z0-9]\.[a-zA-Z]{2,}$ ]]; then
        echo "Error: Invalid domain format. Use format: example.com"
        exit 1
    fi
}

# Function to add a new client
add_client() {
    echo "Adding client: $FULL_DOMAIN"
    
    # Create self-signed certificate (will be replaced by Let's Encrypt later)
    openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
        -keyout "${SSL_DIR}/${FULL_DOMAIN}.key" \
        -out "${SSL_DIR}/${FULL_DOMAIN}.crt" \
        -subj "/CN=${FULL_DOMAIN}" \
        -addext "subjectAltName=DNS:${FULL_DOMAIN}"
    
    # Create NGINX configuration
    cat > "${NGINX_CONF}/${FULL_DOMAIN}.conf" << EOF
# GTM server configuration for ${FULL_DOMAIN}
server {
    listen 443 ssl;
    server_name ${FULL_DOMAIN};

    # SSL configuration
    ssl_certificate /etc/nginx/ssl/client-domains/${FULL_DOMAIN}.crt;
    ssl_certificate_key /etc/nginx/ssl/client-domains/${FULL_DOMAIN}.key;
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_prefer_server_ciphers on;
    ssl_ciphers 'EECDH+AESGCM:EDH+AESGCM:AES256+EECDH:AES256+EDH';
    
    # SSL session cache
    ssl_session_cache shared:SSL:10m;
    ssl_session_timeout 10m;
    
    # GTM server proxy settings
    location / {
        proxy_pass http://gtm-server:8080;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_set_header X-Forwarded-Host \$host;
        proxy_set_header X-Forwarded-Port \$server_port;
        
        # Increase timeouts for GTM server
        proxy_connect_timeout 300;
        proxy_send_timeout 300;
        proxy_read_timeout 300;
        
        # Cache settings
        proxy_cache nginx_cache;
        proxy_cache_valid 200 302 10m;
        proxy_cache_valid 404 1m;
        proxy_cache_use_stale error timeout updating http_500 http_502 http_503 http_504;
        add_header X-Cache-Status \$upstream_cache_status;
    }
}
EOF

    # Update the main HTTP redirect server block
    grep -q "${FULL_DOMAIN}" nginx/conf.d/default.conf || sed -i "/server_name /s/;/ ${FULL_DOMAIN};/" nginx/conf.d/default.conf
    
    echo "Client configuration created for ${FULL_DOMAIN}"
    echo ""
    echo "IMPORTANT: Instruct client to create an A record (not CNAME):"
    echo "--------------------------------"
    echo "Type: A"
    echo "Name: ${SUBDOMAIN}"
    echo "Value: $(curl -s ifconfig.me || echo 'YOUR_SERVER_IP')"
    echo "TTL: Auto"
    echo "--------------------------------"
    echo ""
    echo "Client implementation code:"
    echo "--------------------------------"
    echo "<!-- Google Tag Manager -->"
    echo "<script>"
    echo "(function(w,d,s,l,i){w[l]=w[l]||[];w[l].push({'gtm.start':"
    echo "new Date().getTime(),event:'gtm.js'});var f=d.getElementsByTagName(s)[0],"
    echo "j=d.createElement(s),dl=l!='dataLayer'?'&l='+l:'';j.async=true;j.src="
    echo "'https://${FULL_DOMAIN}/gtm.js?id='+i+dl;f.parentNode.insertBefore(j,f);"
    echo "})(window,document,'script','dataLayer','GTM-5P367G2M');"
    echo "</script>"
    echo "<!-- End Google Tag Manager -->"
    echo ""
    echo "<!-- Google Tag Manager (noscript) -->"
    echo "<noscript><iframe src=\"https://${FULL_DOMAIN}/ns.html?id=GTM-5P367G2M\""
    echo "height=\"0\" width=\"0\" style=\"display:none;visibility:hidden\"></iframe></noscript>"
    echo "<!-- End Google Tag Manager (noscript) -->"
    echo "--------------------------------"
}

# Function to remove a client
remove_client() {
    echo "Removing client: $FULL_DOMAIN"
    
    # Remove NGINX configuration
    rm -f "${NGINX_CONF}/${FULL_DOMAIN}.conf"
    
    # Remove certificates
    rm -f "${SSL_DIR}/${FULL_DOMAIN}.crt" "${SSL_DIR}/${FULL_DOMAIN}.key"
    
    # Remove from HTTP redirect server block
    sed -i "s/ ${FULL_DOMAIN}//" nginx/conf.d/default.conf
    
    echo "Client configuration removed for ${FULL_DOMAIN}"
}

# Main script execution
validate_domain

case $ACTION in
    add)
        add_client
        ;;
    remove)
        remove_client
        ;;
    *)
        echo "Usage: $0 add|remove domain.com [subdomain]"
        echo "Example: $0 add example.com gtm"
        exit 1
        ;;
esac

# Reload NGINX configuration
echo "Reloading NGINX configuration..."
docker-compose exec nginx nginx -s reload

echo "Done!" 