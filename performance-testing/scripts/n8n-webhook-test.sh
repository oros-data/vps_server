#!/bin/bash

# N8N Webhook Performance Testing Script
# Tests webhook processing and workflow execution performance

set -e

# Configuration
N8N_URL="https://n8n.orosdata.com"
WEBHOOK_ENDPOINT="/webhook/test-performance"  # You'll need to create this webhook in N8N
REPORT_DIR="../reports"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}🔗 Starting N8N Webhook Performance Testing${NC}"
echo "Target: $N8N_URL"
echo "Webhook: $WEBHOOK_ENDPOINT"
echo "Report Directory: $REPORT_DIR"
echo "Timestamp: $TIMESTAMP"
echo "=========================================="

# Create report directory
mkdir -p "$REPORT_DIR"

# Function to generate test data
generate_test_data() {
    local test_id="$1"
    cat << EOF
{
    "test_id": "$test_id",
    "timestamp": "$(date -Iseconds)",
    "user_data": {
        "user_id": "user_$((RANDOM % 1000))",
        "action": "performance_test",
        "session_id": "session_$((RANDOM % 100))",
        "page_url": "https://example.com/page_$((RANDOM % 50))",
        "user_agent": "LoadTester/1.0",
        "ip_address": "192.168.1.$((RANDOM % 255))"
    },
    "event_data": {
        "event_name": "page_view",
        "event_category": "engagement",
        "event_value": $((RANDOM % 100)),
        "custom_parameters": {
            "test_parameter_1": "value_$((RANDOM % 10))",
            "test_parameter_2": $((RANDOM % 1000)),
            "test_parameter_3": $([ $((RANDOM % 2)) -eq 0 ] && echo "true" || echo "false")
        }
    }
}
EOF
}

# Function to run webhook load test
run_webhook_test() {
    local test_name="$1"
    local requests="$2"
    local concurrency="$3"
    local delay="$4"
    
    echo -e "\n${YELLOW}🧪 Running: $test_name${NC}"
    echo "Requests: $requests, Concurrency: $concurrency, Delay: ${delay}s"
    
    local results_file="$REPORT_DIR/${test_name}_${TIMESTAMP}.csv"
    echo "timestamp,test_id,http_code,total_time,connect_time,response_size" > "$results_file"
    
    # Run concurrent webhook requests
    for batch in $(seq 1 $((requests / concurrency))); do
        for i in $(seq 1 "$concurrency"); do
            (
                test_id="${test_name}_batch${batch}_req${i}"
                test_data=$(generate_test_data "$test_id")
                
                response=$(curl -s -w "%{http_code},%{time_total},%{time_connect},%{size_download}" \
                    -X POST \
                    -H "Content-Type: application/json" \
                    -d "$test_data" \
                    "$N8N_URL$WEBHOOK_ENDPOINT" 2>/dev/null || echo "000,0,0,0")
                
                echo "$(date -Iseconds),$test_id,$response" >> "$results_file"
            ) &
        done
        
        wait
        
        if [ "$delay" -gt 0 ]; then
            sleep "$delay"
        fi
        
        echo -n "."
    done
    
    echo -e "\n${GREEN}✅ $test_name completed${NC}"
    
    # Generate quick stats
    local total_requests=$(tail -n +2 "$results_file" | wc -l)
    local successful_requests=$(tail -n +2 "$results_file" | grep -c "^[^,]*,[^,]*,2[0-9][0-9]," || echo "0")
    local avg_response_time=$(tail -n +2 "$results_file" | cut -d',' -f5 | awk '{sum+=$1} END {if(NR>0) print sum/NR; else print 0}')
    
    echo "   Total requests: $total_requests"
    echo "   Successful: $successful_requests"
    echo "   Success rate: $(echo "scale=2; $successful_requests * 100 / $total_requests" | bc -l)%"
    echo "   Avg response time: ${avg_response_time}s"
}

# Function to test webhook health
test_webhook_health() {
    echo -e "\n${BLUE}🏥 Testing Webhook Health${NC}"
    
    # Simple health check with basic data
    test_data='{"health_check": true, "timestamp": "'$(date -Iseconds)'"}'
    
    response=$(curl -s -w "HTTP_CODE:%{http_code},TIME:%{time_total}" \
        -X POST \
        -H "Content-Type: application/json" \
        -d "$test_data" \
        "$N8N_URL$WEBHOOK_ENDPOINT" 2>/dev/null || echo "ERROR")
    
    if echo "$response" | grep -q "HTTP_CODE:2[0-9][0-9]"; then
        echo -e "${GREEN}✅ Webhook is responding${NC}"
        echo "$response"
    else
        echo -e "${RED}❌ Webhook health check failed${NC}"
        echo "$response"
        echo -e "\n${YELLOW}💡 Make sure you have created a webhook endpoint at: $WEBHOOK_ENDPOINT${NC}"
        echo "   1. Go to $N8N_URL"
        echo "   2. Create a new workflow with a Webhook node"
        echo "   3. Set the webhook path to: $WEBHOOK_ENDPOINT"
        echo "   4. Add some processing nodes (e.g., Set, HTTP Request)"
        echo "   5. Activate the workflow"
        return 1
    fi
}

# Function to monitor N8N metrics during testing
monitor_n8n_metrics() {
    local duration="$1"
    echo -e "\n${BLUE}📊 Monitoring N8N Metrics for ${duration}s${NC}"
    
    local metrics_file="$REPORT_DIR/n8n_metrics_${TIMESTAMP}.csv"
    echo "timestamp,cpu_usage,memory_usage,active_executions" > "$metrics_file"
    
    for i in $(seq 1 "$duration"); do
        # Get container stats
        stats=$(docker stats n8n --no-stream --format "table {{.CPUPerc}}\t{{.MemUsage}}" | tail -n +2)
        cpu=$(echo "$stats" | awk '{print $1}' | sed 's/%//')
        memory=$(echo "$stats" | awk '{print $2}')
        
        # Try to get N8N specific metrics (if available)
        executions=$(curl -s "$N8N_URL/metrics" 2>/dev/null | grep -o "n8n_.*executions.*" | head -1 || echo "N/A")
        
        echo "$(date -Iseconds),$cpu,$memory,$executions" >> "$metrics_file"
        sleep 1
    done
    
    echo -e "${GREEN}✅ Metrics collection completed${NC}"
}

# Main testing sequence
echo -e "\n${BLUE}=== Phase 1: Health Check ===${NC}"
if ! test_webhook_health; then
    echo -e "\n${RED}❌ Cannot proceed without working webhook${NC}"
    exit 1
fi

echo -e "\n${BLUE}=== Phase 2: Light Load Test ===${NC}"
run_webhook_test "webhook_light" 50 5 1

echo -e "\n${BLUE}=== Phase 3: Medium Load Test ===${NC}"
run_webhook_test "webhook_medium" 200 10 0

echo -e "\n${BLUE}=== Phase 4: Burst Test ===${NC}"
run_webhook_test "webhook_burst" 100 20 0

echo -e "\n${BLUE}=== Phase 5: Sustained Load Test ===${NC}"
# Start metrics monitoring in background
monitor_n8n_metrics 60 &
MONITOR_PID=$!

run_webhook_test "webhook_sustained" 300 15 2

# Wait for monitoring to complete
wait $MONITOR_PID

# Generate summary
echo -e "\n${BLUE}📊 Generating N8N Performance Summary${NC}"
summary_file="$REPORT_DIR/n8n_summary_$TIMESTAMP.txt"

cat > "$summary_file" << EOF
N8N Webhook Performance Testing Summary
Generated: $(date)
Target: $N8N_URL
Webhook: $WEBHOOK_ENDPOINT

=== TEST RESULTS ===
EOF

for csv_file in "$REPORT_DIR"/webhook_*_"$TIMESTAMP".csv; do
    if [ -f "$csv_file" ]; then
        test_name=$(basename "$csv_file" "_$TIMESTAMP.csv")
        echo -e "\n--- $test_name ---" >> "$summary_file"
        
        total=$(tail -n +2 "$csv_file" | wc -l)
        successful=$(tail -n +2 "$csv_file" | grep -c ",2[0-9][0-9]," || echo "0")
        avg_time=$(tail -n +2 "$csv_file" | cut -d',' -f5 | awk '{sum+=$1} END {if(NR>0) print sum/NR; else print 0}')
        
        echo "Total requests: $total" >> "$summary_file"
        echo "Successful: $successful" >> "$summary_file"
        echo "Success rate: $(echo "scale=2; $successful * 100 / $total" | bc -l)%" >> "$summary_file"
        echo "Average response time: ${avg_time}s" >> "$summary_file"
    fi
done

echo -e "\n${GREEN}🎉 N8N performance testing completed!${NC}"
echo "📊 Summary report: $summary_file"
echo -e "\n${YELLOW}💡 View detailed metrics in Grafana:${NC}"
echo "   https://server.orosdata.com/grafana" 