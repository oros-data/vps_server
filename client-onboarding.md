# GTM Server Client Onboarding Guide

This guide explains how to onboard new clients to your GTM server solution with first-party cookies and domain configuration.

## Architecture Overview

Each client will access your GTM server through their own subdomain (e.g., `gtm.clientdomain.com`). This preserves first-party cookies and data collection context.

### Key Benefits:

- **First-Party Data Collection**: All tags fire from the client's own domain
- **Scalable Infrastructure**: Single server hosts multiple client configurations
- **Zero Downtime**: New clients can be added without disrupting existing ones
- **Independent SSL**: Each client can have their own SSL certificate

## Onboarding Process

### 1. Client DNS Configuration

Instruct clients to add an **A record** (not CNAME) in their DNS settings:

```
Type: A record
Name: gtm (or preferred subdomain)
Value: 15.204.58.123 (your server IP)
TTL: Auto
```

> **IMPORTANT**: Using an A record instead of CNAME avoids the Cloudflare cross-account CNAME restriction.

### 2. Server-Side Configuration

Run the client-setup.sh script to configure the server:

```bash
./client-setup.sh add clientdomain.com gtm
```

This will:
- Create server configuration for gtm.clientdomain.com
- Generate temporary SSL certificates
- Update NGINX configuration
- Provide implementation code for the client

### 3. Client Implementation

Provide the client with the GTM implementation code:

```html
<!-- Google Tag Manager -->
<script>
(function(w,d,s,l,i){w[l]=w[l]||[];w[l].push({'gtm.start':
new Date().getTime(),event:'gtm.js'});var f=d.getElementsByTagName(s)[0],
j=d.createElement(s),dl=l!='dataLayer'?'&l='+l:'';j.async=true;j.src=
'https://gtm.clientdomain.com/gtm.js?id='+i+dl;f.parentNode.insertBefore(j,f);
})(window,document,'script','dataLayer','GTM-XXXXXXX');
</script>
<!-- End Google Tag Manager -->

<!-- Google Tag Manager (noscript) -->
<noscript><iframe src="https://gtm.clientdomain.com/ns.html?id=GTM-XXXXXXX"
height="0" width="0" style="display:none;visibility:hidden"></iframe></noscript>
<!-- End Google Tag Manager (noscript) -->
```

### 4. SSL Certificate Setup

After DNS propagation (usually 24-48 hours):

```bash
./ssl-renewal.sh
```

This will:
- Obtain valid SSL certificates from Let's Encrypt
- Install them for the client domain
- Configure automatic renewal

## Managing Existing Clients

### Removing a Client

```bash
./client-setup.sh remove clientdomain.com gtm
```

### Listing All Clients

```bash
ls -la nginx/conf.d/clients/
```

## Troubleshooting

### SSL Certificate Issues

If certificate generation fails:

1. Verify the DNS A record is correctly configured
2. Ensure port 80 is open for Let's Encrypt validation
3. Temporarily disable CDNs or proxies during verification

### Connection Issues

If clients report connection problems:

1. Check the NGINX configuration
2. Verify SSL certificates are valid
3. Inspect server logs: `docker-compose logs nginx`

## Performance Considerations

The setup is optimized for:
- High request throughput with NGINX caching
- Low latency for tag delivery
- Minimal memory footprint per client

For very high-volume clients (>10M events/month), consider dedicated server instances. 