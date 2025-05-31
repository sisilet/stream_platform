#!/bin/bash

# SRT Relay Entry Node Startup Script
# Handles ffmpeg-based fan-out to 3 language mixers

set -euo pipefail

# Configuration
SRT_INPUT_PORT=${SRT_INPUT_PORT:-9998}
MIXER1_IP=${MIXER1_IP:-10.42.0.11}
MIXER2_IP=${MIXER2_IP:-10.42.0.12}
MIXER3_IP=${MIXER3_IP:-10.42.0.13}
MIXER_PORT=${MIXER_PORT:-8001}
LOG_LEVEL=${LOG_LEVEL:-info}
HEALTH_CHECK_PORT=${HEALTH_CHECK_PORT:-8080}

# Logging setup
LOG_FILE="/var/log/srtrelay/relay.log"
exec 1> >(tee -a "$LOG_FILE")
exec 2> >(tee -a "$LOG_FILE" >&2)

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

# Signal handlers for graceful shutdown
cleanup() {
    log "Received shutdown signal, stopping ffmpeg..."
    if [[ -n "${FFMPEG_PID:-}" ]]; then
        kill -TERM "$FFMPEG_PID" 2>/dev/null || true
        wait "$FFMPEG_PID" 2>/dev/null || true
    fi
    if [[ -n "${HEALTH_PID:-}" ]]; then
        kill -TERM "$HEALTH_PID" 2>/dev/null || true
    fi
    log "Shutdown complete"
    exit 0
}

trap cleanup SIGTERM SIGINT

# Validate environment
validate_config() {
    log "Validating configuration..."
    
    # Check if ffmpeg is available
    if ! command -v ffmpeg &> /dev/null; then
        log "ERROR: ffmpeg not found"
        exit 1
    fi
    
    # Validate IP addresses
    for ip in "$MIXER1_IP" "$MIXER2_IP" "$MIXER3_IP"; do
        if ! [[ $ip =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
            log "ERROR: Invalid IP address: $ip"
            exit 1
        fi
    done
    
    log "Configuration validated successfully"
}

# Start health check server
start_health_server() {
    log "Starting health check server on port $HEALTH_CHECK_PORT..."
    
    # Simple HTTP server for health checks
    while true; do
        echo -e "HTTP/1.1 200 OK\r\nContent-Length: 2\r\n\r\nOK" | nc -l -p "$HEALTH_CHECK_PORT" -q 1
    done &
    
    HEALTH_PID=$!
    log "Health check server started with PID $HEALTH_PID"
}

# Wait for network connectivity
wait_for_network() {
    log "Waiting for network connectivity..."
    
    local max_attempts=30
    local attempt=1
    
    while [[ $attempt -le $max_attempts ]]; do
        if ping -c 1 -W 2 "$MIXER1_IP" &>/dev/null; then
            log "Network connectivity confirmed"
            return 0
        fi
        
        log "Network check attempt $attempt/$max_attempts failed, retrying..."
        sleep 2
        ((attempt++))
    done
    
    log "ERROR: Network connectivity check failed after $max_attempts attempts"
    exit 1
}

# Start ffmpeg relay
start_ffmpeg_relay() {
    log "Starting ffmpeg SRT relay..."
    log "Input: srt://:$SRT_INPUT_PORT"
    log "Outputs: srt://$MIXER1_IP:$MIXER_PORT, srt://$MIXER2_IP:$MIXER_PORT, srt://$MIXER3_IP:$MIXER_PORT"
    
    # ffmpeg command with fan-out to 3 mixers
    ffmpeg \
        -loglevel "$LOG_LEVEL" \
        -i "srt://:$SRT_INPUT_PORT?mode=listener&latency=200" \
        -c copy -f mpegts "srt://$MIXER1_IP:$MIXER_PORT?mode=caller&latency=200" \
        -c copy -f mpegts "srt://$MIXER2_IP:$MIXER_PORT?mode=caller&latency=200" \
        -c copy -f mpegts "srt://$MIXER3_IP:$MIXER_PORT?mode=caller&latency=200" \
        -stats_period 30 \
        -y &
    
    FFMPEG_PID=$!
    log "ffmpeg started with PID $FFMPEG_PID"
}

# Monitor ffmpeg process
monitor_ffmpeg() {
    log "Monitoring ffmpeg process..."
    
    while true; do
        if ! kill -0 "$FFMPEG_PID" 2>/dev/null; then
            log "ERROR: ffmpeg process died unexpectedly"
            exit 1
        fi
        sleep 10
    done
}

# Main execution
main() {
    log "=== SRT Relay Entry Node Starting ==="
    log "Version: 1.0"
    log "Configuration:"
    log "  Input Port: $SRT_INPUT_PORT"
    log "  Mixer IPs: $MIXER1_IP, $MIXER2_IP, $MIXER3_IP"
    log "  Mixer Port: $MIXER_PORT"
    log "  Log Level: $LOG_LEVEL"
    
    validate_config
    start_health_server
    wait_for_network
    start_ffmpeg_relay
    monitor_ffmpeg
}

# Run main function
main "$@" 