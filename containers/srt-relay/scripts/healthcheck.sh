#!/bin/bash

# Health Check Script for SRT Relay Entry Node
# Validates that the relay is receiving input and forwarding to mixers

set -euo pipefail

HEALTH_CHECK_PORT=${HEALTH_CHECK_PORT:-8080}
SRT_INPUT_PORT=${SRT_INPUT_PORT:-9998}
MIXER1_IP=${MIXER1_IP:-10.42.0.11}
MIXER_PORT=${MIXER_PORT:-8001}

# Check if health server is responding
check_health_server() {
    if curl -s -f "http://localhost:$HEALTH_CHECK_PORT" >/dev/null 2>&1; then
        return 0
    else
        return 1
    fi
}

# Check if ffmpeg process is running
check_ffmpeg_process() {
    if pgrep -f "ffmpeg.*srt://:$SRT_INPUT_PORT" >/dev/null 2>&1; then
        return 0
    else
        return 1
    fi
}

# Check if SRT input port is listening
check_srt_input() {
    if netstat -ulnp 2>/dev/null | grep -q ":$SRT_INPUT_PORT "; then
        return 0
    else
        return 1
    fi
}

# Check network connectivity to mixers
check_mixer_connectivity() {
    if ping -c 1 -W 2 "$MIXER1_IP" >/dev/null 2>&1; then
        return 0
    else
        return 1
    fi
}

# Main health check
main() {
    local exit_code=0
    
    # Check health server
    if ! check_health_server; then
        echo "FAIL: Health server not responding"
        exit_code=1
    fi
    
    # Check ffmpeg process
    if ! check_ffmpeg_process; then
        echo "FAIL: ffmpeg process not running"
        exit_code=1
    fi
    
    # Check SRT input port
    if ! check_srt_input; then
        echo "FAIL: SRT input port $SRT_INPUT_PORT not listening"
        exit_code=1
    fi
    
    # Check mixer connectivity
    if ! check_mixer_connectivity; then
        echo "FAIL: Cannot reach mixer at $MIXER1_IP"
        exit_code=1
    fi
    
    if [[ $exit_code -eq 0 ]]; then
        echo "OK: All health checks passed"
    fi
    
    exit $exit_code
}

main "$@" 