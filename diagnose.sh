#!/bin/bash

echo "=== GTM Server Diagnostics ==="
echo "Date: $(date)"
echo ""

echo "1. Container Status:"
sudo docker-compose ps
echo ""

echo "2. Testing direct server access (bypassing Cloudflare):"
echo "   Root path:"
curl -I -k https://15.204.58.123/ -H "Host: datalakeops.com" 2>/dev/null | head -5
echo ""
echo "   Grafana path:"
curl -I -k https://15.204.58.123/grafana/ -H "Host: datalakeops.com" 2>/dev/null | head -5
echo ""

echo "3. Testing through Cloudflare:"
echo "   Root path:"
curl -I https://datalakeops.com 2>/dev/null | head -5
echo ""
echo "   Grafana path:"
curl -I https://datalakeops.com/grafana/ 2>/dev/null | head -5
echo ""

echo "4. Recent NGINX logs (last 5 lines):"
sudo docker-compose logs --tail=5 nginx | grep -v "GET /metrics"
echo ""

echo "5. Grafana logs (last 5 lines):"
sudo docker-compose logs --tail=5 grafana
echo ""

echo "=== End Diagnostics ===" 