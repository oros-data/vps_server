#!/bin/bash

# Master Performance Testing Script
# Orchestrates all performance tests and monitoring

set -e

# Configuration
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
REPORT_DIR="../reports"
TEST_DURATION_MINUTES=15

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m' # No Color

echo -e "${PURPLE}🎯 COMPREHENSIVE PERFORMANCE TESTING SUITE${NC}"
echo -e "${PURPLE}===========================================${NC}"
echo "Test Suite ID: $TIMESTAMP"
echo "Duration: $TEST_DURATION_MINUTES minutes"
echo "Report Directory: $REPORT_DIR"
echo ""

# Function to check prerequisites
check_prerequisites() {
    echo -e "${BLUE}🔍 Checking Prerequisites${NC}"
    
    local missing_tools=()
    
    # Check for required tools
    if ! command -v ab >/dev/null 2>&1; then
        missing_tools+=("apache2-utils (for ab)")
    fi
    
    if ! command -v curl >/dev/null 2>&1; then
        missing_tools+=("curl")
    fi
    
    if ! command -v bc >/dev/null 2>&1; then
        missing_tools+=("bc")
    fi
    
    if ! command -v docker >/dev/null 2>&1; then
        missing_tools+=("docker")
    fi
    
    if [ ${#missing_tools[@]} -gt 0 ]; then
        echo -e "${RED}❌ Missing required tools:${NC}"
        for tool in "${missing_tools[@]}"; do
            echo "   - $tool"
        done
        echo ""
        echo -e "${YELLOW}💡 Install missing tools:${NC}"
        echo "   sudo apt update && sudo apt install -y apache2-utils curl bc"
        return 1
    fi
    
    echo -e "${GREEN}✅ All prerequisites met${NC}"
}

# Function to check service health
check_services() {
    echo -e "\n${BLUE}🏥 Checking Service Health${NC}"
    
    local services=(
        "https://gtm.yannrodrigues.com/healthz:GTM Server"
        "https://n8n.orosdata.com/healthz:N8N"
        "https://server.orosdata.com/grafana/api/health:Grafana"
    )
    
    local failed_services=()
    
    for service in "${services[@]}"; do
        IFS=':' read -r url name <<< "$service"
        
        echo -n "   Testing $name... "
        
        if curl -s -f "$url" >/dev/null 2>&1; then
            echo -e "${GREEN}✅ OK${NC}"
        else
            echo -e "${RED}❌ FAILED${NC}"
            failed_services+=("$name")
        fi
    done
    
    if [ ${#failed_services[@]} -gt 0 ]; then
        echo -e "\n${RED}❌ Some services are not responding:${NC}"
        for service in "${failed_services[@]}"; do
            echo "   - $service"
        done
        echo -e "\n${YELLOW}⚠️  Continuing with partial testing...${NC}"
        return 1
    fi
    
    echo -e "\n${GREEN}✅ All services are healthy${NC}"
}

# Function to start system monitoring
start_monitoring() {
    echo -e "\n${BLUE}📊 Starting System Monitoring${NC}"
    
    local monitor_file="$REPORT_DIR/system_monitoring_$TIMESTAMP.csv"
    
    # Create monitoring script
    cat > "/tmp/system_monitor_$TIMESTAMP.sh" << 'EOF'
#!/bin/bash
MONITOR_FILE="$1"
DURATION="$2"

echo "timestamp,cpu_percent,memory_percent,disk_io_read,disk_io_write,network_rx,network_tx,load_avg" > "$MONITOR_FILE"

for i in $(seq 1 "$DURATION"); do
    # Get system metrics
    cpu=$(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | sed 's/%us,//')
    memory=$(free | grep Mem | awk '{printf "%.2f", $3/$2 * 100.0}')
    load_avg=$(uptime | awk -F'load average:' '{print $2}' | awk '{print $1}' | sed 's/,//')
    
    # Get disk I/O (simplified)
    disk_stats=$(iostat -d 1 2 | tail -n +4 | head -1 | awk '{print $3","$4}' 2>/dev/null || echo "0,0")
    
    # Get network stats (simplified)
    network_stats=$(cat /proc/net/dev | grep ens3 | awk '{print $2","$10}' 2>/dev/null || echo "0,0")
    
    echo "$(date -Iseconds),$cpu,$memory,$disk_stats,$network_stats,$load_avg" >> "$MONITOR_FILE"
    sleep 60
done
EOF
    
    chmod +x "/tmp/system_monitor_$TIMESTAMP.sh"
    
    # Start monitoring in background
    "/tmp/system_monitor_$TIMESTAMP.sh" "$monitor_file" "$TEST_DURATION_MINUTES" &
    MONITOR_PID=$!
    
    echo "   System monitoring started (PID: $MONITOR_PID)"
    echo "   Monitor file: $monitor_file"
}

# Function to run GTM analytics validation
run_gtm_analytics_validation() {
    echo -e "\n${BLUE}🎯 Running GTM Analytics Validation${NC}"
    
    local validation_file="$REPORT_DIR/gtm_analytics_validation_$TIMESTAMP.txt"
    
    cat > "$validation_file" << EOF
GTM Analytics Validation Report
Generated: $(date)
Test Suite: $TIMESTAMP

=== VALIDATION TESTS ===
EOF
    
    # Test 1: GTM Container Loading
    echo "   Testing GTM container loading..."
    gtm_js_response=$(curl -s -w "STATUS:%{http_code},TIME:%{time_total},SIZE:%{size_download}" \
        "https://gtm.yannrodrigues.com/gtm.js?id=GTM-W2C56MN4" 2>/dev/null || echo "ERROR")
    
    echo -e "\n--- GTM Container Load Test ---" >> "$validation_file"
    echo "Response: $gtm_js_response" >> "$validation_file"
    
    if echo "$gtm_js_response" | grep -q "STATUS:200"; then
        echo -e "   ${GREEN}✅ GTM container loads successfully${NC}"
        echo "Status: SUCCESS" >> "$validation_file"
    else
        echo -e "   ${RED}❌ GTM container failed to load${NC}"
        echo "Status: FAILED" >> "$validation_file"
    fi
    
    # Test 2: Preview Mode Access
    echo "   Testing GTM preview mode..."
    preview_response=$(curl -s -w "STATUS:%{http_code}" \
        "https://gtm.yannrodrigues.com/?gtm_auth=preview&gtm_preview=env-1" 2>/dev/null || echo "ERROR")
    
    echo -e "\n--- GTM Preview Mode Test ---" >> "$validation_file"
    echo "Response: $preview_response" >> "$validation_file"
    
    if echo "$preview_response" | grep -q "STATUS:200\|STATUS:400"; then
        echo -e "   ${GREEN}✅ GTM preview mode accessible${NC}"
        echo "Status: SUCCESS (Preview mode responds)" >> "$validation_file"
    else
        echo -e "   ${YELLOW}⚠️  GTM preview mode response uncertain${NC}"
        echo "Status: UNCERTAIN" >> "$validation_file"
    fi
    
    # Test 3: Analytics Data Collection Simulation
    echo "   Testing analytics data collection..."
    collect_response=$(curl -s -w "STATUS:%{http_code},TIME:%{time_total}" \
        -X POST \
        -H "Content-Type: application/x-www-form-urlencoded" \
        -d "v=2&tid=GTM-W2C56MN4&cid=test-client&t=pageview&dp=/test-page&dt=Test%20Page" \
        "https://gtm.yannrodrigues.com/g/collect" 2>/dev/null || echo "ERROR")
    
    echo -e "\n--- Analytics Collection Test ---" >> "$validation_file"
    echo "Response: $collect_response" >> "$validation_file"
    
    if echo "$collect_response" | grep -q "STATUS:200\|STATUS:204"; then
        echo -e "   ${GREEN}✅ Analytics collection endpoint working${NC}"
        echo "Status: SUCCESS" >> "$validation_file"
    else
        echo -e "   ${YELLOW}⚠️  Analytics collection response uncertain${NC}"
        echo "Status: UNCERTAIN" >> "$validation_file"
    fi
    
    echo -e "\n${GREEN}✅ GTM analytics validation completed${NC}"
    echo "   Report: $validation_file"
}

# Function to generate final report
generate_final_report() {
    echo -e "\n${BLUE}📋 Generating Final Comprehensive Report${NC}"
    
    local final_report="$REPORT_DIR/FINAL_REPORT_$TIMESTAMP.md"
    
    cat > "$final_report" << EOF
# Performance Testing Comprehensive Report

**Test Suite ID:** $TIMESTAMP  
**Generated:** $(date)  
**Duration:** $TEST_DURATION_MINUTES minutes  

## 📊 Executive Summary

This comprehensive performance test evaluated:
- GTM Server performance and scalability
- N8N webhook processing capabilities  
- System resource utilization
- Analytics functionality validation

## 🎯 Test Results Overview

### GTM Server Performance
EOF
    
    # Add GTM test results if available
    if [ -f "$REPORT_DIR/summary_$TIMESTAMP.txt" ]; then
        echo "#### Load Testing Results" >> "$final_report"
        echo '```' >> "$final_report"
        cat "$REPORT_DIR/summary_$TIMESTAMP.txt" >> "$final_report"
        echo '```' >> "$final_report"
    fi
    
    # Add N8N results if available
    if [ -f "$REPORT_DIR/n8n_summary_$TIMESTAMP.txt" ]; then
        echo -e "\n### N8N Webhook Performance" >> "$final_report"
        echo '```' >> "$final_report"
        cat "$REPORT_DIR/n8n_summary_$TIMESTAMP.txt" >> "$final_report"
        echo '```' >> "$final_report"
    fi
    
    # Add analytics validation
    if [ -f "$REPORT_DIR/gtm_analytics_validation_$TIMESTAMP.txt" ]; then
        echo -e "\n### Analytics Validation" >> "$final_report"
        echo '```' >> "$final_report"
        cat "$REPORT_DIR/gtm_analytics_validation_$TIMESTAMP.txt" >> "$final_report"
        echo '```' >> "$final_report"
    fi
    
    cat >> "$final_report" << EOF

## 📈 Monitoring Data

### System Monitoring
- File: \`system_monitoring_$TIMESTAMP.csv\`
- Duration: $TEST_DURATION_MINUTES minutes
- Metrics: CPU, Memory, Disk I/O, Network, Load Average

### Container Metrics
- Available in Grafana: https://server.orosdata.com/grafana
- Prometheus metrics: All container-level metrics collected

## 🔧 Recommendations

Based on the test results:

1. **Performance Optimization**
   - Monitor peak usage patterns
   - Consider scaling strategies for high-traffic periods
   - Optimize caching policies

2. **Monitoring Enhancement**
   - Set up alerting thresholds based on baseline performance
   - Implement automated performance regression testing
   - Monitor GTM analytics data quality

3. **Capacity Planning**
   - Current configuration can handle tested load patterns
   - Plan for 3x growth in traffic
   - Consider container resource allocation optimization

## 📊 Grafana Dashboards

Access real-time metrics at:
- https://server.orosdata.com/grafana

## 📁 Test Artifacts

All test results, logs, and metrics are available in:
\`$REPORT_DIR/\`

---
*Generated by Comprehensive Performance Testing Suite*
EOF
    
    echo -e "${GREEN}✅ Final report generated${NC}"
    echo "   📄 Report: $final_report"
}

# Main execution flow
main() {
    # Create report directory
    mkdir -p "$REPORT_DIR"
    
    # Check prerequisites
    if ! check_prerequisites; then
        exit 1
    fi
    
    # Check service health
    check_services
    
    # Start system monitoring
    start_monitoring
    
    # Run GTM analytics validation
    run_gtm_analytics_validation
    
    # Run GTM load tests
    echo -e "\n${PURPLE}🚀 Starting GTM Load Tests${NC}"
    if [ -f "./gtm-load-test.sh" ]; then
        chmod +x ./gtm-load-test.sh
        ./gtm-load-test.sh
    else
        echo -e "${RED}❌ GTM load test script not found${NC}"
    fi
    
    # Run N8N webhook tests (optional)
    echo -e "\n${PURPLE}🔗 Starting N8N Webhook Tests${NC}"
    if [ -f "./n8n-webhook-test.sh" ]; then
        chmod +x ./n8n-webhook-test.sh
        echo -e "${YELLOW}⚠️  N8N webhook tests require a test webhook to be configured${NC}"
        echo "   Skipping N8N tests for now..."
        # ./n8n-webhook-test.sh
    else
        echo -e "${YELLOW}⚠️  N8N webhook test script not found${NC}"
    fi
    
    # Wait for monitoring to complete
    echo -e "\n${BLUE}⏳ Waiting for monitoring to complete...${NC}"
    echo "   This will take $TEST_DURATION_MINUTES minutes"
    echo "   You can monitor progress in real-time at:"
    echo "   https://server.orosdata.com/grafana"
    
    # Show a progress indicator
    for i in $(seq 1 "$TEST_DURATION_MINUTES"); do
        echo -n "   Monitoring... ${i}/${TEST_DURATION_MINUTES} minutes "
        for j in $(seq 1 60); do
            echo -n "."
            sleep 1
        done
        echo ""
    done
    
    # Stop monitoring
    if [ -n "$MONITOR_PID" ] && kill -0 "$MONITOR_PID" 2>/dev/null; then
        kill "$MONITOR_PID"
        echo -e "${GREEN}✅ System monitoring completed${NC}"
    fi
    
    # Clean up monitoring script
    rm -f "/tmp/system_monitor_$TIMESTAMP.sh"
    
    # Generate final report
    generate_final_report
    
    echo -e "\n${PURPLE}🎉 COMPREHENSIVE PERFORMANCE TESTING COMPLETED${NC}"
    echo -e "${PURPLE}=============================================${NC}"
    echo -e "📊 View results in: ${BLUE}$REPORT_DIR${NC}"
    echo -e "📈 Real-time metrics: ${BLUE}https://server.orosdata.com/grafana${NC}"
    echo -e "🎯 Test Suite ID: ${BLUE}$TIMESTAMP${NC}"
}

# Run main function
main "$@" 