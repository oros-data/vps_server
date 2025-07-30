#!/bin/bash

echo "=== GTM Server Diagnostics ==="
echo "Date: $(date)"
echo ""

echo "1. Container Status:"
sudo docker-compose ps
echo ""

echo "2. Testing direct server access (bypassing Cloudflare):"
echo "   Root path:"
curl -I -k https://51.81.220.69/ -H "Host: orosdata.com" 2>/dev/null | head -5
echo ""
echo "   Grafana path:"
curl -I -k https://51.81.220.69/grafana/ -H "Host: orosdata.com" 2>/dev/null | head -5
echo ""

echo "3. Testing through Cloudflare:"
echo "   Root path:"
curl -I https://orosdata.com 2>/dev/null | head -5
echo ""
echo "   Grafana path:"
curl -I https://orosdata.com/grafana/ 2>/dev/null | head -5
echo ""

echo "4. Recent NGINX logs (last 5 lines):"
sudo docker-compose logs --tail=5 nginx | grep -v "GET /metrics"
echo ""

echo "5. Grafana logs (last 5 lines):"
sudo docker-compose logs --tail=5 grafana
echo ""

echo "=== End Diagnostics ===" 