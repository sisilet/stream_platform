# Slide Splitter Container for Multilingual Streaming System
# Converts 32:9 slides to 16:9 format and distributes to language mixers

FROM ubuntu:22.04

LABEL maintainer="Streaming System Team"
LABEL description="Slide Splitter for converting and distributing presentation slides"
LABEL version="1.0"

# Avoid interactive prompts during build
ENV DEBIAN_FRONTEND=noninteractive

# Install system dependencies
RUN apt-get update && apt-get install -y \
    # FFmpeg with SRT support
    ffmpeg \
    # Network utilities
    curl \
    netcat-openbsd \
    # Process management
    supervisor \
    # Cleanup
    && rm -rf /var/lib/apt/lists/* \
    && apt-get clean

# Create non-root user
RUN useradd -m -u 1000 -s /bin/bash splitter

# Create application directories
RUN mkdir -p /app/scripts /app/logs /tmp/splitter \
    && chown -R splitter:splitter /app /tmp/splitter

# Copy application scripts
COPY scripts/ /app/scripts/
COPY test-splitter.sh /app/

# Set permissions
RUN chmod +x /app/scripts/*.sh /app/test-splitter.sh \
    && chown -R splitter:splitter /app

# Switch to non-root user
USER splitter
WORKDIR /app

# Environment variables with defaults
ENV MIXER1_IP=10.42.0.11
ENV MIXER2_IP=10.42.0.12
ENV MIXER3_IP=10.42.0.13
ENV MIXER_PORT=8002
ENV SRT_INPUT_PORT=9999
ENV HEALTH_CHECK_PORT=8080
ENV LOG_LEVEL=info
ENV OUTPUT_WIDTH=1920
ENV OUTPUT_HEIGHT=1080
ENV VIDEO_QUALITY=18

# Expose ports
EXPOSE 9999/udp 8080/tcp

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=30s --retries=3 \
    CMD curl -f http://localhost:${HEALTH_CHECK_PORT}/ || exit 1

# Start the application
ENTRYPOINT ["./scripts/start-splitter.sh"] 