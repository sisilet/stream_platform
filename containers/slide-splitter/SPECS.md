# Slide Splitter Container Specification

**Version:** 3.1  
**Component:** Slide Splitter  
**Type:** Docker Container  
**Date:** 2025-01-27

## 📋 Overview

**Purpose:** Receives ultra-wide (32:9) slide presentations from ProPresenter and converts them to standard 16:9 format for distribution to all Language Mixers.

**Role in System:** Video format converter that takes single ultra-wide slide stream via Tailscale and distributes correctly formatted slides to all three language mixers.

**Dependencies:** Tailscale mesh network, ProPresenter Mac, Language Mixer VMs

---

## 🔧 Technical Specifications

### Hardware Requirements
```yaml
CPU: 2 vCPUs (Intel/AMD x64)
RAM: 4 GB
Storage: 20 GB SSD
Network: 50 Mbps sustained, dual NIC support
OS: Ubuntu 22.04 LTS (Container Base)
Location: Azure Container Instance
```

### Software Stack
```yaml
Primary Software: ffmpeg v6.1+ with SRT support and video filters
Runtime Dependencies: Docker v24.0+, Tailscale v1.50+
Supporting Tools: Health check endpoints, container metrics
Container Image: Custom Ubuntu 22.04 with ffmpeg/SRT
```

---

## 🌐 Network Configuration

### Interface Configuration
- **Primary Interface:** Tailscale mesh (100.x.x.y/32) - Ingress from ProPresenter
- **Secondary Interface:** Internal cloud subnet (10.42.0.2/24) - Egress to Language Mixers

### Port Mapping
| Port | Protocol | Direction | Purpose |
|------|----------|-----------|---------|
| 9999 | UDP | Inbound | SRT input from ProPresenter |
| 8080 | TCP | Inbound | Health check endpoint |
| 8002 | UDP | Outbound | SRT output to all Language Mixers |
| 41641 | UDP | Bidirectional | Tailscale mesh communication |

### Firewall Rules
```yaml
Inbound:
  - 41641/udp: Tailscale mesh connectivity
  - 9999/udp: SRT input from ProPresenter
  - 8080/tcp: Health check monitoring
Outbound:
  - 10.42.0.0/24: Internal subnet access to mixers
  - 53/udp: DNS resolution
```

---

## 🎬 Stream Processing

### Input Streams
```yaml
Source: ProPresenter via Tailscale SRT
Format: 3840x1080 (32:9) @ 1fps, H.264, 1 Mbps (static slide presentations)
Protocol: SRT
Bandwidth: 1 Mbps sustained
```

### Processing Logic
```yaml
Transformation: Video scaling and cropping from 32:9 to 16:9 aspect ratio
Method: ffmpeg video filter pipeline with center crop and letterboxing
Quality Settings: H.264 libx264, CRF 18 (visually lossless for presentation content)
Latency Target: <100ms processing delay
```

### Output Streams
```yaml
Destination: Three Language Mixers (10.42.0.11, 10.42.0.12, 10.42.0.13)
Format: 1920x1080 (16:9) @ 1fps, H.264, 1 Mbps
Protocol: SRT to port 8002 on each mixer
Bandwidth: 3 Mbps total output (1 Mbps × 3)
```

---

## 🚀 Deployment Configuration

### Environment Variables
```yaml
MIXER1_IP: 10.42.0.11 (Language Mixer 1 IP address)
MIXER2_IP: 10.42.0.12 (Language Mixer 2 IP address)
MIXER3_IP: 10.42.0.13 (Language Mixer 3 IP address)
MIXER_PORT: 8002 (SRT output port for mixers)
SRT_INPUT_PORT: 9999 (SRT input port for ProPresenter)
HEALTH_CHECK_PORT: 8080 (Health monitoring port)
LOG_LEVEL: info (Logging verbosity: debug, info, warn, error)
OUTPUT_WIDTH: 1920 (Output video width)
OUTPUT_HEIGHT: 1080 (Output video height)
VIDEO_QUALITY: 18 (Video quality CRF value for H.264)
```

### Resource Limits
```yaml
CPU Limit: 2 cores (1 core sustained, 2 cores burst)
Memory Limit: 2 GB (1GB working set, 2GB limit)
Storage Limit: 5 GB (500MB logs, 5GB temporary)
Network Limit: 25 Mbps (10 Mbps sustained, 25 Mbps burst)
```

### Health Monitoring
```yaml
Health Check: HTTP GET to :8080/ returns "OK" (200) or error details
Metrics: ffmpeg process status, SRT connection count, video processing rate
Alerts: Container restart, SRT disconnection, video processing errors
```

---

## 🛠️ Operations

### Startup Sequence
1. Container initialization and health check server start
2. Tailscale mesh connectivity validation
3. SRT input port binding for ProPresenter connection
4. ffmpeg process launch with video pipeline and 3-way output
5. Health status reporting to orchestration system

### Shutdown Sequence
1. Stop accepting new SRT connections (close listener)
2. Graceful ffmpeg termination via SIGTERM
3. Wait for video processing completion (maximum 30 seconds)
4. Force termination if needed via SIGKILL
5. Container exit and cleanup

### Common Issues
| Problem | Cause | Solution |
|---------|-------|----------|
| Aspect Ratio Issues | Incorrect scaling parameters | Verify video filter chain configuration |
| SRT Connection Drops | ProPresenter network issues | Auto-reconnect with status monitoring |
| High CPU Usage | Complex video processing | Optimize ffmpeg settings for 1fps content |
| Output Quality Loss | Aggressive compression | Adjust CRF value for better quality |

---

## 📊 Performance Requirements

### SLA Targets
```yaml
Uptime: 99.9% availability during events
Latency: <200ms end-to-end from input to mixer output
Quality: Lossless or near-lossless video conversion
Recovery Time: 1 minute maximum after failure
```

### Resource Usage
```yaml
CPU: 20-40% typical usage (burst to 80% during slide transitions)
Memory: 500MB-1GB typical usage (2GB maximum)
Network: 5-10 Mbps typical (25 Mbps burst)
Storage: <50MB logs per hour
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
- [ ] **Video Processing Test**: Validate 32:9 to 16:9 conversion accuracy
- [ ] **SRT Input Test**: Verify slide stream reception from ProPresenter
- [ ] **Fanout Test**: Confirm slides delivered to all 3 mixers
- [ ] **Quality Test**: Verify visual quality preservation after conversion

### Manual Validation
- [ ] **Aspect Ratio Validation**: Confirm correct 16:9 output format
- [ ] **Content Centering**: Verify slides are properly centered
- [ ] **Letterboxing Check**: Validate black bars if needed for aspect ratio
- [ ] **End-to-End Slides**: Test full slide delivery pipeline

---

## 📚 References

- **Related Components:** [ProPresenter Mac](../../local/propresenter/SPECS.md), [Language Mixers](../../vms/language-mixer-windows/SPECS.md)
- **External Documentation:** [FFmpeg Video Filters](https://ffmpeg.org/ffmpeg-filters.html), [SRT Protocol Docs](https://github.com/Haivision/srt)
- **Configuration Examples:** [Docker Compose](./docker-compose.yml), [Video Filter Config](./filters.conf)

---

**Document Control:**
- **Template Version:** 1.0
- **Last Updated:** 2025-01-27  
- **Next Review:** 2025-04-27 