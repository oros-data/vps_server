# GTM Server with NGINX Setup

This repository contains a Docker Compose configuration for running a Google Tag Manager server with NGINX as a reverse proxy and full monitoring capabilities.

## System Requirements

- Server with at least 2GB RAM
- Docker and Docker Compose installed
- Domain name (we're using datalakeops.com in this example)

## Setup Instructions

### 1. Clone this repository

```bash
git clone <repository-url>
cd <repository-directory>
```

### 2. Configure SSL certificates

You need to obtain SSL certificates for your domain. Since you're using Cloudflare, you have two options:

#### Option A: Use Cloudflare Origin Certificates (recommended)

1. Log in to your Cloudflare account
2. Navigate to your domain (datalakeops.com)
3. Go to SSL/TLS > Origin Server
4. Click "Create Certificate"
5. Follow the prompts to create a new certificate
6. Download both the certificate and private key
7. Save these files to the `nginx/ssl` directory:
   ```bash
   # Save the certificate as:
   nano nginx/ssl/datalakeops.com.crt
   # Paste the certificate content then save (Ctrl+X, Y, Enter)
   
   # Save the private key as:
   nano nginx/ssl/datalakeops.com.key
   # Paste the private key content then save (Ctrl+X, Y, Enter)
   ```

#### Option B: Use Let's Encrypt

1. Install certbot:
   ```bash
   sudo apt-get update
   sudo apt-get install certbot
   ```
2. Generate certificates:
   ```bash
   sudo certbot certonly --standalone -d datalakeops.com -d www.datalakeops.com
   ```
3. Copy certificates to the nginx/ssl directory:
   ```bash
   sudo cp /etc/letsencrypt/live/datalakeops.com/fullchain.pem nginx/ssl/datalakeops.com.crt
   sudo cp /etc/letsencrypt/live/datalakeops.com/privkey.pem nginx/ssl/datalakeops.com.key
   ```

### 3. Update GTM Container Configuration

Edit the `docker-compose.yml` file to set your actual GTM container configuration:

```yaml
gtm-server:
  image: gcr.io/cloud-tagging-10302018/gtm-cloud-image:stable
  environment:
    - CONTAINER_CONFIG=your_container_config
  restart: always
```

Replace `your_container_config` with your actual GTM container configuration ID from Google Tag Manager.

### 4. Configure DNS

Make sure your domain (datalakeops.com) has A records pointing to your server's IP address.

In Cloudflare:
1. Navigate to DNS management for datalakeops.com
2. Add or update A records for:
   - datalakeops.com (pointing to your server IP)
   - www.datalakeops.com (pointing to your server IP)
3. Make sure the proxy status is enabled (orange cloud)
4. Under SSL/TLS setting, set the mode to "Full" or "Full (strict)" if using Cloudflare Origin certificates

### 5. Start the stack

```bash
docker-compose up -d
```

### 6. Test the setup

- Visit https://datalakeops.com - should redirect to your GTM server
- Visit https://datalakeops.com/grafana/ - should show the Grafana dashboard (login with admin/!DataLake123*)
- Visit https://datalakeops.com/prometheus/ - should prompt for auth (use admin/admin)

## Monitoring

The setup includes the following monitoring components:

- **NGINX Metrics Exporter**: Collects metrics from NGINX
- **Node Exporter**: Collects system metrics
- **Prometheus**: Stores all metrics
- **Grafana**: Visualizes metrics with dashboards

Access Grafana at https://datalakeops.com/grafana/ with credentials:
- Username: admin
- Password: !DataLake123* (change this in production)

## Security Considerations

1. Change the default credentials in:
   - `nginx/auth/.htpasswd` for Prometheus access
   - `docker-compose.yml` for Grafana admin password

2. Make sure your firewall only allows:
   - HTTP (port 80)
   - HTTPS (port 443)
   - SSH (port 22)

3. Set up regular backups of:
   - Configuration files
   - Prometheus data
   - Grafana data

## Performance Tuning

The NGINX configuration includes:
- Caching for static assets
- Rate limiting to protect against abuse
- Compression for faster page loads

For higher traffic (beyond 1M events per month), consider:
1. Increasing the cache size in nginx.conf
2. Adjusting the rate limiting settings
3. Scaling to multiple servers with load balancing 