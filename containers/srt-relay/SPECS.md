# SRT Relay Entry Node Specification

**Version:** 3.1  
**Component:** SRT Relay Entry Node  
**Type:** Docker Container  
**Date:** 2025-01-27

## 📋 Overview

**Purpose:** Receives high-quality audio/video streams from Local Streamer and fans them out to three Language Mixer VMs.

**Role in System:** Critical fanout hub that accepts single 6-channel SRT stream via Tailscale and distributes identical copies to all language mixers in cloud subnet.

**Dependencies:** Tailscale mesh network, Local Streamer, Language Mixer VMs

---

## 🔧 Technical Specifications

### Hardware Requirements
```yaml
CPU: 4 vCPUs (Intel/AMD x64)
RAM: 8 GB
Storage: 50 GB SSD
Network: 100 Mbps sustained, dual NIC support
OS: Ubuntu 22.04 LTS (Container Base)
Location: Azure Container Instance
```

### Software Stack
```yaml
Primary Software: ffmpeg v6.1+ with SRT support
Runtime Dependencies: Docker v24.0+, Tailscale v1.50+
Supporting Tools: Prometheus metrics, rsyslog, health check server
Container Image: Custom Ubuntu 22.04 with ffmpeg/SRT
```

---

## 🌐 Network Configuration

### Interface Configuration
- **Primary Interface:** Tailscale mesh (100.x.x.x/32) - Ingress from Local Streamer
- **Secondary Interface:** Internal cloud subnet (10.42.0.1/24) - Egress to Language Mixers

### Port Mapping
| Port | Protocol | Direction | Purpose |
|------|----------|-----------|---------|
| 9998 | UDP | Inbound | SRT input from Local Streamer |
| 8080 | TCP | Inbound | Health check endpoint |
| 8001 | UDP | Outbound | SRT output to all Language Mixers |
| 41641 | UDP | Bidirectional | Tailscale mesh communication |

### Firewall Rules
```yaml
Inbound:
  - 41641/udp: Tailscale mesh connectivity
  - 9998/udp: SRT input from Local Streamer
  - 8080/tcp: Health check monitoring
Outbound:
  - 10.42.0.0/24: Internal subnet access to mixers
  - 53/udp: DNS resolution
```

---

## 🎬 Stream Processing

### Input Streams
```yaml
Source: Local Streamer via Tailscale SRT
Format: 1920x1080@30fps, H.264, 5-8 Mbps + 6-channel AAC audio (384 kbps)
Protocol: SRT with 200ms latency buffer
Bandwidth: 8 Mbps sustained
```

### Processing Logic
```yaml
Transformation: Stream copy (no transcoding) for minimal latency
Method: Single ffmpeg process with 3 SRT outputs
Quality Settings: Identical to input (stream copy)
Latency Target: <50ms additional processing delay
```

### Output Streams
```yaml
Destination: Three Language Mixers (10.42.0.11, 10.42.0.12, 10.42.0.13)
Format: Identical to input (1920x1080@30fps, 6-channel audio)
Protocol: SRT to port 8001 on each mixer
Bandwidth: 24 Mbps total output (8 Mbps × 3)
```

---

## 🚀 Deployment Configuration

### Environment Variables
```yaml
MIXER1_IP: 10.42.0.11 (Language Mixer 1 IP address)
MIXER2_IP: 10.42.0.12 (Language Mixer 2 IP address)
MIXER3_IP: 10.42.0.13 (Language Mixer 3 IP address)
MIXER_PORT: 8001 (SRT output port for mixers)
SRT_INPUT_PORT: 9998 (SRT input port for Local Streamer)
HEALTH_CHECK_PORT: 8080 (Health monitoring port)
LOG_LEVEL: info (Logging verbosity: debug, info, warn, error)
SRT_LATENCY: 200 (SRT latency buffer in milliseconds)
```

### Resource Limits
```yaml
CPU Limit: 4 cores (2 cores sustained, 4 cores burst)
Memory Limit: 4 GB (2GB working set, 4GB limit)
Storage Limit: 10 GB (1GB logs, 10GB temporary)
Network Limit: 100 Mbps (50 Mbps sustained, 100 Mbps burst)
```

### Health Monitoring
```yaml
Health Check: HTTP GET to :8080/ returns "OK" (200) or error details
Metrics: CPU/memory usage, stream status, connection count, error rates
Alerts: Container restart, high resource usage (>80%), connectivity issues
```

---

## 🛠️ Operations

### Startup Sequence
1. Container initialization and health check server start
2. Tailscale mesh connectivity validation
3. SRT input port binding and listener setup
4. ffmpeg process launch with 3-way fanout configuration
5. Health status reporting to orchestration system

### Shutdown Sequence
1. Stop accepting new SRT connections (close listener)
2. Graceful ffmpeg termination via SIGTERM
3. Wait for stream completion (maximum 30 seconds)
4. Force termination if needed via SIGKILL
5. Container exit and cleanup

### Common Issues
| Problem | Cause | Solution |
|---------|-------|----------|
| SRT Connection Drops | Network instability | Auto-reconnect with exponential backoff |
| High CPU Usage | Inefficient encoding | Switch to stream copy mode (no transcoding) |
| Memory Leaks | Long-running ffmpeg | Scheduled container restart every 24 hours |
| Mixer Connectivity | Cloud network issues | Health check validation with retry logic |

---

## 📊 Performance Requirements

### SLA Targets
```yaml
Uptime: 99.9% availability during events
Latency: <500ms end-to-end from input to mixer output
Quality: <0.1% frame loss under normal conditions
Recovery Time: 2 minutes maximum after failure
```

### Resource Usage
```yaml
CPU: 30-50% typical usage (burst to 100% during startup)
Memory: 1-2GB typical usage (4GB maximum)
Network: 30-50 Mbps typical (100 Mbps burst)
Storage: <100MB logs per hour
```

---

## 🔒 Security Configuration

### Access Control
```yaml
Authentication: Tailscale mesh authentication for ingress
Authorization: IP-based access control for cloud subnet
Encryption: SRT native encryption support
```

### Hardening
```yaml
Container Security: Non-root execution (uid 1000), minimal capabilities
OS Security: Read-only root filesystem where possible
Network Security: Strict firewall rules, egress filtering to mixer IPs only
```

---

## 🧪 Testing Requirements

### Automated Tests
- [ ] **Container Build Test**: Verify successful Docker image build and startup
- [ ] **Health Endpoint Test**: Confirm HTTP health check returns 200 OK
- [ ] **SRT Input Test**: Validate SRT stream reception and processing
- [ ] **Fanout Test**: Verify identical streams delivered to all 3 mixers
- [ ] **Resource Limits Test**: Confirm CPU/memory usage within bounds
- [ ] **Signal Handling Test**: Test graceful shutdown via SIGTERM

### Manual Validation
- [ ] **End-to-End Streaming**: Full pipeline test with Local Streamer input
- [ ] **Network Connectivity**: Verify Tailscale mesh and cloud subnet access
- [ ] **Performance Monitoring**: Check latency and throughput under load
- [ ] **Failure Recovery**: Test container restart and stream resumption

---

## 📚 References

- **Related Components:** [Local Streamer](../../local/streamer/SPECS.md), [Language Mixers](../../vms/language-mixer-windows/SPECS.md)
- **External Documentation:** [SRT Protocol Docs](https://github.com/Haivision/srt), [FFmpeg SRT Guide](https://ffmpeg.org/ffmpeg-protocols.html#srt)
- **Configuration Examples:** [Docker Compose](./docker-compose.yml), [Environment File](./env.example)

---

**Document Control:**
- **Template Version:** 1.0
- **Last Updated:** 2025-01-27  
- **Next Review:** 2025-04-27 