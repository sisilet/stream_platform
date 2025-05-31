#!/bin/bash

# Slide Splitter Startup Script
# Converts 32:9 slides to 16:9 format and distributes to language mixers

set -euo pipefail

# Configuration from environment variables
MIXER1_IP="${MIXER1_IP:-10.42.0.11}"
MIXER2_IP="${MIXER2_IP:-10.42.0.12}"
MIXER3_IP="${MIXER3_IP:-10.42.0.13}"
MIXER_PORT="${MIXER_PORT:-8002}"
SRT_INPUT_PORT="${SRT_INPUT_PORT:-9999}"
HEALTH_CHECK_PORT="${HEALTH_CHECK_PORT:-8080}"
LOG_LEVEL="${LOG_LEVEL:-info}"
OUTPUT_WIDTH="${OUTPUT_WIDTH:-1920}"
OUTPUT_HEIGHT="${OUTPUT_HEIGHT:-1080}"
VIDEO_QUALITY="${VIDEO_QUALITY:-18}"

# Logging function
log() {
    local level="$1"
    shift
    echo "$(date -Iseconds) [$level] $*" >&2
}

log_info() { log "INFO" "$@"; }
log_warn() { log "WARN" "$@"; }
log_error() { log "ERROR" "$@"; }

# Signal handlers
cleanup() {
    log_info "Received shutdown signal, cleaning up..."
    
    # Stop ffmpeg gracefully
    if [[ -n "${FFMPEG_PID:-}" ]]; then
        log_info "Stopping ffmpeg process (PID: $FFMPEG_PID)"
        kill -TERM "$FFMPEG_PID" 2>/dev/null || true
        
        # Wait for graceful shutdown
        local count=0
        while kill -0 "$FFMPEG_PID" 2>/dev/null && [[ $count -lt 30 ]]; do
            sleep 1
            ((count++))
        done
        
        # Force kill if still running
        if kill -0 "$FFMPEG_PID" 2>/dev/null; then
            log_warn "Force killing ffmpeg process"
            kill -KILL "$FFMPEG_PID" 2>/dev/null || true
        fi
    fi
    
    # Stop health check server
    if [[ -n "${HEALTH_PID:-}" ]]; then
        log_info "Stopping health check server (PID: $HEALTH_PID)"
        kill -TERM "$HEALTH_PID" 2>/dev/null || true
    fi
    
    log_info "Cleanup completed"
    exit 0
}

# Set up signal handlers
trap cleanup SIGTERM SIGINT

# Health check server
start_health_server() {
    log_info "Starting health check server on port $HEALTH_CHECK_PORT"
    
    # Simple HTTP server using netcat
    while true; do
        {
            echo -e "HTTP/1.1 200 OK\r\nContent-Length: 2\r\n\r\nOK"
        } | nc -l -p "$HEALTH_CHECK_PORT" -q 1 2>/dev/null || true
        sleep 0.1
    done &
    
    HEALTH_PID=$!
    log_info "Health check server started (PID: $HEALTH_PID)"
}

# Network connectivity check
check_network_connectivity() {
    log_info "Checking network connectivity to mixers..."
    
    local mixers=("$MIXER1_IP" "$MIXER2_IP" "$MIXER3_IP")
    local failed=0
    
    for mixer in "${mixers[@]}"; do
        if ! nc -z -w 5 "$mixer" "$MIXER_PORT" 2>/dev/null; then
            log_warn "Cannot reach mixer at $mixer:$MIXER_PORT"
            ((failed++))
        else
            log_info "Mixer $mixer:$MIXER_PORT is reachable"
        fi
    done
    
    if [[ $failed -gt 0 ]]; then
        log_warn "$failed mixer(s) are not reachable, but continuing anyway"
    fi
}

# Start FFmpeg slide processing
start_ffmpeg() {
    log_info "Starting FFmpeg slide splitter..."
    
    # Build FFmpeg command
    local ffmpeg_cmd=(
        "ffmpeg"
        "-hide_banner"
        "-loglevel" "$LOG_LEVEL"
        "-i" "srt://:${SRT_INPUT_PORT}?mode=listener"
        "-vf" "scale=${OUTPUT_WIDTH}:${OUTPUT_HEIGHT}:force_original_aspect_ratio=decrease,pad=${OUTPUT_WIDTH}:${OUTPUT_HEIGHT}:(ow-iw)/2:(oh-ih)/2"
        "-c:v" "libx264"
        "-preset" "fast"
        "-crf" "$VIDEO_QUALITY"
        "-f" "mpegts" "srt://${MIXER1_IP}:${MIXER_PORT}?mode=caller"
        "-f" "mpegts" "srt://${MIXER2_IP}:${MIXER_PORT}?mode=caller"
        "-f" "mpegts" "srt://${MIXER3_IP}:${MIXER_PORT}?mode=caller"
    )
    
    log_info "FFmpeg command: ${ffmpeg_cmd[*]}"
    
    # Start FFmpeg in background
    "${ffmpeg_cmd[@]}" &
    FFMPEG_PID=$!
    
    log_info "FFmpeg started (PID: $FFMPEG_PID)"
    
    # Monitor FFmpeg process
    while kill -0 "$FFMPEG_PID" 2>/dev/null; do
        sleep 5
    done
    
    # FFmpeg exited
    wait "$FFMPEG_PID"
    local exit_code=$?
    
    if [[ $exit_code -eq 0 ]]; then
        log_info "FFmpeg exited normally"
    else
        log_error "FFmpeg exited with code $exit_code"
        exit $exit_code
    fi
}

# Validate configuration
validate_config() {
    log_info "Validating configuration..."
    
    # Check required environment variables
    local required_vars=("MIXER1_IP" "MIXER2_IP" "MIXER3_IP")
    for var in "${required_vars[@]}"; do
        if [[ -z "${!var:-}" ]]; then
            log_error "Required environment variable $var is not set"
            exit 1
        fi
    done
    
    # Validate video dimensions
    if [[ ! "$OUTPUT_WIDTH" =~ ^[0-9]+$ ]] || [[ ! "$OUTPUT_HEIGHT" =~ ^[0-9]+$ ]]; then
        log_error "Invalid video dimensions: ${OUTPUT_WIDTH}x${OUTPUT_HEIGHT}"
        exit 1
    fi
    
    # Validate video quality
    if [[ ! "$VIDEO_QUALITY" =~ ^[0-9]+$ ]] || [[ "$VIDEO_QUALITY" -lt 0 ]] || [[ "$VIDEO_QUALITY" -gt 51 ]]; then
        log_error "Invalid video quality (CRF): $VIDEO_QUALITY (must be 0-51)"
        exit 1
    fi
    
    log_info "Configuration validation passed"
}

# Main function
main() {
    log_info "Slide Splitter Starting..."
    log_info "Version: 1.0"
    log_info "Input Port: $SRT_INPUT_PORT"
    log_info "Output Resolution: ${OUTPUT_WIDTH}x${OUTPUT_HEIGHT}"
    log_info "Video Quality (CRF): $VIDEO_QUALITY"
    log_info "Mixer 1: $MIXER1_IP:$MIXER_PORT"
    log_info "Mixer 2: $MIXER2_IP:$MIXER_PORT"
    log_info "Mixer 3: $MIXER3_IP:$MIXER_PORT"
    
    # Validate configuration
    validate_config
    
    # Start health check server
    start_health_server
    
    # Check network connectivity
    check_network_connectivity
    
    # Start FFmpeg processing
    start_ffmpeg
}

# Run main function
main "$@" 