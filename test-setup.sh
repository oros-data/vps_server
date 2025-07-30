#!/bin/bash

# Test script for GTM Server with NGINX and Grafana setup
echo "===== Testing GTM Server, NGINX and Grafana Setup ====="

# Check if domain resolves
echo -e "\n[1] Checking DNS resolution..."
for domain in orosdata.com server.orosdata.com gtm.orosdata.com; do
    if ping -c 1 $domain &> /dev/null; then
        echo "✅ $domain resolves correctly"
    else
        echo "❌ $domain does not resolve correctly"
    fi
done

# Test URLs with new structure
echo -e "\n[2] Testing new domain structure..."

# Test main landing page
echo "Testing main landing page..."
MAIN_STATUS=$(curl -s -o /dev/null -w "%{http_code}" https://orosdata.com)
echo "   https://orosdata.com → Status: $MAIN_STATUS"

# Test server tools
echo "Testing server tools..."
SERVER_STATUS=$(curl -s -o /dev/null -w "%{http_code}" https://server.orosdata.com/grafana/)
echo "   https://server.orosdata.com/grafana/ → Status: $SERVER_STATUS"

# Test GTM endpoint  
echo "Testing GTM server..."
GTM_STATUS=$(curl -s -o /dev/null -w "%{http_code}" https://gtm.orosdata.com)
echo "   https://gtm.orosdata.com → Status: $GTM_STATUS"

# Restart the services
echo -e "\n[2] Restarting services..."
sudo docker-compose down
sudo docker-compose up -d
echo "✅ Services restarted"

# Wait for services to start up
echo -e "\n[3] Waiting for services to start up (30 seconds)..."
sleep 30

# Check if all containers are running
echo -e "\n[4] Checking container status..."
CONTAINERS=$(sudo docker-compose ps -q | wc -l)
RUNNING=$(sudo docker-compose ps | grep "Up" | wc -l)
echo "Total containers: $CONTAINERS, Running: $RUNNING"
if [ "$CONTAINERS" -eq "$RUNNING" ]; then
    echo "✅ All containers are running"
else
    echo "❌ Not all containers are running"
    sudo docker-compose ps
fi

# Test NGINX connectivity
echo -e "\n[5] Testing NGINX HTTP to HTTPS redirect..."
HTTP_STATUS=$(curl -s -o /dev/null -w "%{http_code}" http://orosdata.com)
if [ "$HTTP_STATUS" -eq 301 ] || [ "$HTTP_STATUS" -eq 302 ]; then
    echo "✅ HTTP to HTTPS redirect works (status $HTTP_STATUS)"
else
    echo "❌ HTTP to HTTPS redirect failed (status $HTTP_STATUS)"
fi

# Test NGINX HTTPS connectivity
echo -e "\n[6] Testing NGINX HTTPS connectivity..."
HTTPS_STATUS=$(curl -s -k -o /dev/null -w "%{http_code}" https://orosdata.com)
if [ "$HTTPS_STATUS" -ge 200 ] && [ "$HTTPS_STATUS" -lt 400 ]; then
    echo "✅ HTTPS connection works (status $HTTPS_STATUS)"
else
    echo "❌ HTTPS connection failed (status $HTTPS_STATUS)"
fi

# Test GTM Server
echo -e "\n[7] Testing GTM Server..."
GTM_STATUS=$(curl -s -k -o /dev/null -w "%{http_code}" https://orosdata.com)
if [ "$GTM_STATUS" -ge 200 ] && [ "$GTM_STATUS" -lt 400 ]; then
    echo "✅ GTM Server is accessible (status $GTM_STATUS)"
else
    echo "❌ GTM Server is not accessible (status $GTM_STATUS)"
    echo "   Checking GTM Server logs..."
    sudo docker-compose logs --tail=20 gtm-server
fi

# Test Grafana
echo -e "\n[8] Testing Grafana..."
GRAFANA_STATUS=$(curl -s -k -o /dev/null -w "%{http_code}" https://orosdata.com/grafana)
if [ "$GRAFANA_STATUS" -ge 200 ] && [ "$GRAFANA_STATUS" -lt 400 ]; then
    echo "✅ Grafana is accessible (status $GRAFANA_STATUS)"
else
    echo "❌ Grafana is not accessible (status $GRAFANA_STATUS)"
    echo "   Checking Grafana logs..."
    sudo docker-compose logs --tail=20 grafana
    echo "   Checking NGINX logs..."
    sudo docker-compose logs --tail=20 nginx
fi

# Test Prometheus
echo -e "\n[9] Testing Prometheus..."
PROMETHEUS_STATUS=$(curl -s -k -o /dev/null -w "%{http_code}" https://orosdata.com/prometheus/)
if [ "$PROMETHEUS_STATUS" -eq 401 ] || [ "$PROMETHEUS_STATUS" -ge 200 ] && [ "$PROMETHEUS_STATUS" -lt 400 ]; then
    echo "✅ Prometheus is accessible (status $PROMETHEUS_STATUS)"
else
    echo "❌ Prometheus is not accessible (status $PROMETHEUS_STATUS)"
    echo "   Checking Prometheus logs..."
    sudo docker-compose logs --tail=20 prometheus
fi

# Summary
echo -e "\n===== Testing Complete ====="
echo "If you encountered any issues, here are the most common fixes:"
echo "1. DNS issues: Make sure your domain has an A record pointing to your server IP"
echo "2. SSL issues: Check that your certificates are correctly installed in nginx/ssl/"
echo "3. Redirect loops: The updated configuration should fix Grafana redirect loops"
echo "4. Container issues: Check the logs with 'sudo docker-compose logs <service-name>'"
echo ""
echo "For deeper debugging run:"
echo "- 'sudo docker-compose logs nginx' to check NGINX logs"
echo "- 'sudo docker-compose logs grafana' to check Grafana logs"
echo "- 'sudo docker-compose logs gtm-server' to check GTM Server logs" 