#!/bin/bash

# GTM Server Load Testing Script
# Tests various GTM endpoints with different load patterns

set -e

# Configuration
GTM_URL="https://gtm.yannrodrigues.com"
GTM_CONTAINER_ID="GTM-W2C56MN4"
REPORT_DIR="../reports"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}🚀 Starting GTM Server Performance Testing${NC}"
echo "Target: $GTM_URL"
echo "Container ID: $GTM_CONTAINER_ID"
echo "Report Directory: $REPORT_DIR"
echo "Timestamp: $TIMESTAMP"
echo "=========================================="

# Create report directory
mkdir -p "$REPORT_DIR"

# Function to run load test with Apache Bench
run_ab_test() {
    local test_name="$1"
    local url="$2"
    local requests="$3"
    local concurrency="$4"
    local output_file="$REPORT_DIR/${test_name}_${TIMESTAMP}.txt"
    
    echo -e "\n${YELLOW}🧪 Running: $test_name${NC}"
    echo "URL: $url"
    echo "Requests: $requests, Concurrency: $concurrency"
    
    ab -n "$requests" -c "$concurrency" -g "$REPORT_DIR/${test_name}_${TIMESTAMP}.gnuplot" "$url" > "$output_file" 2>&1
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✅ $test_name completed successfully${NC}"
        # Extract key metrics
        grep "Requests per second" "$output_file" | head -1
        grep "Time per request" "$output_file" | head -1
        grep "Failed requests" "$output_file"
    else
        echo -e "${RED}❌ $test_name failed${NC}"
    fi
}

# Function to run curl-based stress test
run_curl_stress() {
    local test_name="$1"
    local url="$2"
    local duration="$3"
    local parallel="$4"
    
    echo -e "\n${YELLOW}🧪 Running: $test_name${NC}"
    echo "URL: $url"
    echo "Duration: ${duration}s, Parallel: $parallel"
    
    # Run parallel curl requests for specified duration
    for i in $(seq 1 "$parallel"); do
        (
            end_time=$(($(date +%s) + duration))
            count=0
            while [ $(date +%s) -lt $end_time ]; do
                curl -s -o /dev/null -w "%{http_code},%{time_total},%{time_connect},%{time_starttransfer}\n" "$url" >> "$REPORT_DIR/${test_name}_worker${i}_${TIMESTAMP}.csv"
                ((count++))
            done
            echo "Worker $i completed $count requests"
        ) &
    done
    
    wait
    
    # Combine results
    cat "$REPORT_DIR/${test_name}_worker"*"_${TIMESTAMP}.csv" > "$REPORT_DIR/${test_name}_combined_${TIMESTAMP}.csv"
    rm "$REPORT_DIR/${test_name}_worker"*"_${TIMESTAMP}.csv"
    
    echo -e "${GREEN}✅ $test_name completed${NC}"
}

# Test 1: GTM Health Check - Light Load
echo -e "\n${BLUE}=== Test 1: Health Check - Light Load ===${NC}"
run_ab_test "health_light" "$GTM_URL/healthz" 100 10

# Test 2: GTM Health Check - Medium Load
echo -e "\n${BLUE}=== Test 2: Health Check - Medium Load ===${NC}"
run_ab_test "health_medium" "$GTM_URL/healthz" 500 25

# Test 3: GTM JavaScript - Light Load
echo -e "\n${BLUE}=== Test 3: GTM JavaScript - Light Load ===${NC}"
run_ab_test "gtmjs_light" "$GTM_URL/gtm.js?id=$GTM_CONTAINER_ID" 100 10

# Test 4: GTM JavaScript - Medium Load
echo -e "\n${BLUE}=== Test 4: GTM JavaScript - Medium Load ===${NC}"
run_ab_test "gtmjs_medium" "$GTM_URL/gtm.js?id=$GTM_CONTAINER_ID" 500 25

# Test 5: GTM Collect Endpoint - Simulated Analytics
echo -e "\n${BLUE}=== Test 5: GTM Collect - Analytics Simulation ===${NC}"
run_curl_stress "gtm_collect" "$GTM_URL/g/collect?v=2&tid=$GTM_CONTAINER_ID&cid=test&t=pageview&dp=/test" 30 5

# Test 6: High Concurrency Stress Test
echo -e "\n${BLUE}=== Test 6: High Concurrency Stress Test ===${NC}"
run_ab_test "stress_high" "$GTM_URL/healthz" 1000 50

# Generate Summary Report
echo -e "\n${BLUE}📊 Generating Summary Report${NC}"
summary_file="$REPORT_DIR/summary_$TIMESTAMP.txt"

cat > "$summary_file" << EOF
GTM Server Performance Testing Summary
Generated: $(date)
Target: $GTM_URL
Container ID: $GTM_CONTAINER_ID

=== TEST RESULTS ===
EOF

# Extract key metrics from each test
for test_file in "$REPORT_DIR"/*_"$TIMESTAMP".txt; do
    if [ -f "$test_file" ]; then
        test_name=$(basename "$test_file" "_$TIMESTAMP.txt")
        echo -e "\n--- $test_name ---" >> "$summary_file"
        grep -E "(Requests per second|Time per request|Failed requests|Transfer rate)" "$test_file" >> "$summary_file" 2>/dev/null || echo "No metrics found" >> "$summary_file"
    fi
done

echo -e "\n${GREEN}🎉 Performance testing completed!${NC}"
echo "📊 Summary report: $summary_file"
echo -e "\n${YELLOW}💡 To view Grafana metrics:${NC}"
echo "   https://server.orosdata.com/grafana"
echo -e "\n${YELLOW}💡 To view Prometheus metrics:${NC}"
echo "   https://server.orosdata.com:9090 (if exposed)"

# Display quick summary
echo -e "\n${BLUE}=== Quick Summary ===${NC}"
if [ -f "$summary_file" ]; then
    grep "Requests per second" "$summary_file" | head -5
fi 