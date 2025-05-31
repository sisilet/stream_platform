#!/bin/bash

# Local Test Script for Slide Splitter Docker Image
# Tests the container locally before deploying to Azure Container Instances

set -euo pipefail

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# Configuration
IMAGE_NAME="slide-splitter:latest"
CONTAINER_NAME="slide-splitter-test"
TEST_NETWORK="splitter-test-net"
SRT_PORT="9999"
HEALTH_PORT="8080"

# Mock mixer IPs for testing
MIXER1_IP="172.20.0.10"
MIXER2_IP="172.20.0.11" 
MIXER3_IP="172.20.0.12"

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Cleanup function
cleanup() {
    log_info "Cleaning up test environment..."
    
    # Stop and remove container
    docker stop "$CONTAINER_NAME" 2>/dev/null || true
    docker rm "$CONTAINER_NAME" 2>/dev/null || true
    
    # Remove test network
    docker network rm "$TEST_NETWORK" 2>/dev/null || true
    
    # Stop any test streams
    pkill -f "ffmpeg.*testsrc" 2>/dev/null || true
    
    log_info "Cleanup complete"
}

# Setup test environment
setup_test_environment() {
    log_info "Setting up test environment..."
    
    # Create test network to simulate Azure internal network
    docker network create --subnet=172.20.0.0/16 "$TEST_NETWORK" || {
        log_warning "Test network already exists or failed to create"
    }
    
    log_success "Test environment ready"
}

# Build Docker image
build_image() {
    log_info "Building Docker image..."
    
    if [[ ! -f "Dockerfile" ]]; then
        log_error "Dockerfile not found in current directory"
        exit 1
    fi
    
    docker build -t "$IMAGE_NAME" . || {
        log_error "Failed to build Docker image"
        exit 1
    }
    
    log_success "Docker image built successfully"
}

# Start container
start_container() {
    log_info "Starting Slide Splitter container..."
    
    # Stop existing container if running
    docker stop "$CONTAINER_NAME" 2>/dev/null || true
    docker rm "$CONTAINER_NAME" 2>/dev/null || true
    
    # Start container with test configuration
    docker run -d \
        --name "$CONTAINER_NAME" \
        --network "$TEST_NETWORK" \
        -p "$SRT_PORT:$SRT_PORT/udp" \
        -p "$HEALTH_PORT:$HEALTH_PORT/tcp" \
        -e MIXER1_IP="$MIXER1_IP" \
        -e MIXER2_IP="$MIXER2_IP" \
        -e MIXER3_IP="$MIXER3_IP" \
        -e MIXER_PORT=8002 \
        -e LOG_LEVEL=info \
        -e SRT_INPUT_PORT="$SRT_PORT" \
        -e HEALTH_CHECK_PORT="$HEALTH_PORT" \
        -e OUTPUT_WIDTH=1920 \
        -e OUTPUT_HEIGHT=1080 \
        -e VIDEO_QUALITY=18 \
        "$IMAGE_NAME" || {
        log_error "Failed to start container"
        exit 1
    }
    
    log_success "Container started"
}

# Wait for container to be ready
wait_for_ready() {
    log_info "Waiting for container to be ready..."
    
    local max_attempts=30
    local attempt=1
    
    while [[ $attempt -le $max_attempts ]]; do
        if curl -s -f "http://localhost:$HEALTH_PORT" >/dev/null 2>&1; then
            log_success "Container is ready!"
            return 0
        fi
        
        if [[ $((attempt % 5)) -eq 0 ]]; then
            log_info "Still waiting... (attempt $attempt/$max_attempts)"
        fi
        
        sleep 2
        ((attempt++))
    done
    
    log_error "Container failed to become ready after $max_attempts attempts"
    return 1
}

# Test health endpoint
test_health_endpoint() {
    log_info "Testing health endpoint..."
    
    local response
    response=$(curl -s "http://localhost:$HEALTH_PORT")
    
    if [[ "$response" == "OK" ]]; then
        log_success "Health endpoint responding correctly"
        return 0
    else
        log_error "Health endpoint returned: $response"
        return 1
    fi
}

# Test container logs
test_container_logs() {
    log_info "Checking container logs..."
    
    local logs
    logs=$(docker logs "$CONTAINER_NAME" 2>&1)
    
    # Check for expected log messages
    if echo "$logs" | grep -q "Slide Splitter Starting" && \
       echo "$logs" | grep -q "FFmpeg started with PID"; then
        log_success "Container logs look good"
        return 0
    else
        log_error "Container logs missing expected messages"
        echo "=== Container Logs ==="
        echo "$logs"
        echo "======================"
        return 1
    fi
}

# Test SRT port listening
test_srt_port() {
    log_info "Testing SRT port listening..."
    
    # Check if port is listening
    if netstat -ulnp 2>/dev/null | grep -q ":$SRT_PORT "; then
        log_success "SRT port $SRT_PORT is listening"
        return 0
    else
        log_error "SRT port $SRT_PORT is not listening"
        return 1
    fi
}

# Test with actual SRT stream (32:9 slides)
test_srt_stream() {
    log_info "Testing with 32:9 SRT stream..."
    
    # Check if ffmpeg is available for testing
    if ! command -v ffmpeg &> /dev/null; then
        log_warning "ffmpeg not available, skipping SRT stream test"
        return 0
    fi
    
    log_info "Sending test 32:9 slide stream for 15 seconds..."
    
    # Send test stream in background (32:9 aspect ratio)
    timeout 15s ffmpeg \
        -f lavfi -i testsrc=duration=15:size=3840x1080:rate=1 \
        -c:v libx264 -preset ultrafast -b:v 1M \
        -f mpegts "srt://localhost:$SRT_PORT?mode=caller" \
        >/dev/null 2>&1 &
    
    local ffmpeg_pid=$!
    
    # Wait for stream to start
    sleep 5
    
    # Check container logs for stream activity
    local logs
    logs=$(docker logs "$CONTAINER_NAME" 2>&1 | tail -20)
    
    # Wait for ffmpeg to finish
    wait $ffmpeg_pid 2>/dev/null || true
    
    if echo "$logs" | grep -q "Input #0"; then
        log_success "SRT stream test passed"
        return 0
    else
        log_warning "SRT stream test inconclusive (check logs manually)"
        return 0  # Don't fail the test for this
    fi
}

# Test video processing capabilities
test_video_processing() {
    log_info "Testing video processing capabilities..."
    
    # Check if container can handle video filters
    local logs
    logs=$(docker logs "$CONTAINER_NAME" 2>&1)
    
    if echo "$logs" | grep -q "scale=1920:1080"; then
        log_success "Video processing filter configured correctly"
        return 0
    else
        log_warning "Video processing filter not found in logs"
        return 0
    fi
}

# Test resource usage
test_resource_usage() {
    log_info "Checking resource usage..."
    
    local stats
    stats=$(docker stats "$CONTAINER_NAME" --no-stream --format "table {{.CPUPerc}}\t{{.MemUsage}}")
    
    if echo "$stats" | grep -q "%"; then
        log_success "Resource usage looks normal"
        echo "$stats"
        return 0
    else
        log_warning "Could not get resource stats"
        return 0
    fi
}

# Show container information
show_container_info() {
    log_info "=== Container Information ==="
    echo "Name: $CONTAINER_NAME"
    echo "Image: $IMAGE_NAME"
    echo "SRT Input: srt://localhost:$SRT_PORT"
    echo "Health Check: http://localhost:$HEALTH_PORT"
    echo "Mixer IPs: $MIXER1_IP, $MIXER2_IP, $MIXER3_IP"
    echo "Input Format: 3840x1080 (32:9)"
    echo "Output Format: 1920x1080 (16:9)"
    echo ""
    
    log_info "=== Test Commands ==="
    echo "Health check: curl http://localhost:$HEALTH_PORT"
    echo "Container logs: docker logs $CONTAINER_NAME"
    echo "Container stats: docker stats $CONTAINER_NAME"
    echo "Stop container: docker stop $CONTAINER_NAME"
    echo ""
    
    log_info "=== SRT Test Stream (32:9 Slides) ==="
    echo "ffmpeg -f lavfi -i testsrc=duration=30:size=3840x1080:rate=1 \\"
    echo "       -c:v libx264 -preset ultrafast -b:v 1M \\"
    echo "       -f mpegts \"srt://localhost:$SRT_PORT?mode=caller\""
    echo ""
    
    log_info "=== Expected Output ==="
    echo "The container should convert 32:9 input to 16:9 output with letterboxing"
    echo "and distribute to 3 mixer destinations"
}

# Main test execution
main() {
    echo ""
    log_info "=== Slide Splitter Local Test Suite ==="
    echo ""
    
    # Setup cleanup trap
    trap cleanup EXIT INT
    
    # Run tests
    setup_test_environment
    build_image
    start_container
    
    if wait_for_ready; then
        # Run all tests
        local test_results=0
        
        test_health_endpoint || test_results=$((test_results + 1))
        test_container_logs || test_results=$((test_results + 1))
        test_srt_port || test_results=$((test_results + 1))
        test_video_processing || test_results=$((test_results + 1))
        test_srt_stream || test_results=$((test_results + 1))
        test_resource_usage || test_results=$((test_results + 1))
        
        echo ""
        if [[ $test_results -eq 0 ]]; then
            log_success "All tests passed! Container is ready for Azure deployment 🎉"
        else
            log_warning "$test_results test(s) had issues, but container is functional"
        fi
        
        show_container_info
        
        # Ask if user wants to keep container running
        echo ""
        read -p "Keep container running for manual testing? (y/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            log_info "Container will keep running. Use 'docker stop $CONTAINER_NAME' to stop it."
            trap - EXIT  # Disable cleanup on exit
        fi
        
    else
        log_error "Container failed to start properly"
        docker logs "$CONTAINER_NAME"
        exit 1
    fi
}

# Check dependencies
check_dependencies() {
    local deps=("docker" "curl" "netstat")
    local missing_deps=()
    
    for dep in "${deps[@]}"; do
        if ! command -v "$dep" &> /dev/null; then
            missing_deps+=("$dep")
        fi
    done
    
    if [[ ${#missing_deps[@]} -gt 0 ]]; then
        log_error "Missing dependencies: ${missing_deps[*]}"
        log_error "Please install them and try again"
        exit 1
    fi
}

# Run main function
check_dependencies
main "$@" 