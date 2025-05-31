# Language Mixer Windows VM Specification

**Version:** 3.1  
**Component:** Language Mixer VMs (3x instances)  
**Type:** Windows Virtual Machine  
**Date:** 2025-01-27

## Overview

The Language Mixer VMs are Windows-based virtual machines that receive audio/video streams from the SRT Relay and slide content from the Slide Splitter, combine them with language-specific audio channels, and stream the final output to YouTube via RTMP.

## Hardware Specifications (per VM)

- **CPU**: 4 vCPUs (Intel/AMD x64)
- **RAM**: 8 GB
- **Storage**: 50 GB SSD
- **Network**: 50 Mbps sustained bandwidth
- **OS**: Windows Server 2022 (or Windows 10/11 Pro)
- **Location**: Azure cloud subnet 10.42.0.0/24

## Network Configuration

### IP Addresses
- **Mixer 1**: 10.42.0.11 (Original Language)
- **Mixer 2**: 10.42.0.12 (Language A)
- **Mixer 3**: 10.42.0.13 (Language B)

### Firewall Rules
- **Inbound**: 
  - Internal subnet SRT (8001-8002/tcp)
  - RDP (3389/tcp) - for management only
- **Outbound**: 
  - YouTube RTMP (1935/tcp)
  - DNS (53)
  - Windows Updates (443/tcp)

### Port Configuration
- **A/V Input**: 8001/tcp (from SRT Relay)
- **Slide Input**: 8002/tcp (from Slide Splitter)
- **RTMP Output**: 1935/tcp (to YouTube)

## Software Requirements

### Primary Software
- **OBS Studio v29+**: Main streaming and mixing software
- **Alternative**: ffmpeg v5.0+ for command-line operation
- **Runtime**: Microsoft Visual C++ Redistributable 2019+, .NET Framework 4.8+

### Supporting Software
- **Audio Processing**: VB-Cable or VoiceMeeter for advanced audio routing
- **Monitoring**: Prometheus windows-exporter for metrics
- **System**: Windows Service management for auto-restart
- **Security**: Windows Defender Firewall, Windows Updates

### Optional Software
- **Backup Streaming**: XSplit or Wirecast as OBS alternative
- **Remote Management**: TeamViewer or Windows Remote Desktop
- **Performance Monitoring**: Process Monitor, Resource Monitor

## Stream Processing Configuration

### Input Streams

**Audio/Video Stream (from SRT Relay):**
- **Source**: SRT from Relay Entry Node (10.42.0.1:8001)
- **Format**: 1920x1080@30fps, H.264, 5-8 Mbps
- **Audio**: 48kHz, 16-bit, 6-channel AAC, 384 kbps
  - Channels 1-2: Original presenter audio (stereo)
  - Channels 3-4: Interpreter 1 audio (Language A, stereo)
  - Channels 5-6: Interpreter 2 audio (Language B, stereo)

**Slide Stream (from Slide Splitter):**
- **Source**: SRT from Slide Splitter (10.42.0.2:8002)
- **Format**: 1920x1080@1fps, H.264, 1 Mbps
- **Audio**: None (slides only)

### Audio Channel Mapping

**Mixer 1 (Original Language):**
```bash
# OBS Audio Filter: Channel selection 1-2
# ffmpeg equivalent:
-filter:a "pan=stereo|c0=c0|c1=c1"
```

**Mixer 2 (Language A):**
```bash
# OBS Audio Filter: Channel selection 3-4
# ffmpeg equivalent:
-filter:a "pan=stereo|c0=c2|c1=c3"
```

**Mixer 3 (Language B):**
```bash
# OBS Audio Filter: Channel selection 5-6
# ffmpeg equivalent:
-filter:a "pan=stereo|c0=c4|c1=c5"
```

### Output Configuration

**RTMP Stream to YouTube:**
- **Format**: 1920x1080@30fps, H.264, 6 Mbps
- **Audio**: 48kHz, stereo AAC, 128 kbps
- **Protocol**: RTMP over TCP
- **Destinations**:
  - Mixer 1: YouTube Channel 1
  - Mixer 2: YouTube Channel 2
  - Mixer 3: YouTube Channel 3

## OBS Studio Configuration

### Scene Setup
1. **Scene 1: Main Stream**
   - Source 1: SRT input (A/V from relay)
   - Source 2: SRT input (slides from splitter)
   - Layout: Picture-in-picture or side-by-side

### Audio Configuration
- **Audio Input**: SRT stream (6-channel)
- **Audio Filter**: Channel mapping for language selection
- **Audio Output**: Stereo downmix for RTMP
- **Audio Monitoring**: Disabled to prevent feedback

### Video Configuration
- **Canvas Resolution**: 1920x1080
- **Output Resolution**: 1920x1080
- **FPS**: 30
- **Encoder**: Hardware (NVENC/AMF) if available, otherwise x264

### Streaming Settings
- **Service**: Custom RTMP
- **Server**: rtmp://a.rtmp.youtube.com/live2/
- **Stream Key**: [YouTube Stream Key per channel]
- **Bitrate**: 6000 kbps
- **Keyframe Interval**: 2 seconds

## Alternative FFmpeg Configuration

For command-line operation without OBS:

```bash
# Mixer 1 (Original Language)
ffmpeg \
  -i srt://10.42.0.1:8001 \
  -i srt://10.42.0.2:8002 \
  -filter_complex "[0:v][1:v]overlay=W-w-10:10[v];[0:a]pan=stereo|c0=c0|c1=c1[a]" \
  -map "[v]" -map "[a]" \
  -c:v libx264 -preset fast -b:v 6M \
  -c:a aac -b:a 128k \
  -f flv rtmp://a.rtmp.youtube.com/live2/[STREAM_KEY_1]

# Mixer 2 (Language A)
ffmpeg \
  -i srt://10.42.0.1:8001 \
  -i srt://10.42.0.2:8002 \
  -filter_complex "[0:v][1:v]overlay=W-w-10:10[v];[0:a]pan=stereo|c0=c2|c1=c3[a]" \
  -map "[v]" -map "[a]" \
  -c:v libx264 -preset fast -b:v 6M \
  -c:a aac -b:a 128k \
  -f flv rtmp://a.rtmp.youtube.com/live2/[STREAM_KEY_2]

# Mixer 3 (Language B)
ffmpeg \
  -i srt://10.42.0.1:8001 \
  -i srt://10.42.0.2:8002 \
  -filter_complex "[0:v][1:v]overlay=W-w-10:10[v];[0:a]pan=stereo|c0=c4|c1=c5[a]" \
  -map "[v]" -map "[a]" \
  -c:v libx264 -preset fast -b:v 6M \
  -c:a aac -b:a 128k \
  -f flv rtmp://a.rtmp.youtube.com/live2/[STREAM_KEY_3]
```

## Performance Requirements

### Resource Limits
- **CPU**: 2 cores sustained, 4 cores burst
- **Memory**: 4GB working set, 6GB limit
- **Network**: 25 Mbps sustained, 50 Mbps burst
- **Storage**: 10GB logs, 20GB temporary

### Quality Metrics
- **Uptime**: 99.9% availability during events
- **Frame Loss**: <0.1% under normal conditions
- **Audio Sync**: ±50ms maximum drift
- **Stream Stability**: <1% disconnection rate

## Security Configuration

### Windows Security
- **User Account**: Non-administrator service account
- **Windows Defender**: Enabled with streaming exceptions
- **Windows Updates**: Automatic security updates
- **Remote Access**: RDP restricted to management subnet

### Network Security
- **Firewall**: Windows Defender Firewall enabled
- **Ingress**: Only required SRT ports from internal subnet
- **Egress**: Only YouTube RTMP and essential services
- **VPN**: No external VPN required (internal subnet only)

## Deployment Configuration

### Azure Virtual Machine
- **Resource Group**: streaming-rg
- **Location**: East US (same as containers)
- **Availability Set**: For redundancy across fault domains
- **Managed Disks**: Premium SSD for OS and applications

### Environment-Specific Settings
- **Production**: 4 vCPU, 8GB RAM, Standard_D4s_v3
- **Staging**: 2 vCPU, 4GB RAM, Standard_D2s_v3
- **Development**: 2 vCPU, 4GB RAM, Standard_D2s_v3

## Monitoring and Health Checks

### Health Indicators
- **OBS/ffmpeg Process**: Running and responsive
- **SRT Connections**: Both A/V and slide inputs active
- **RTMP Connection**: YouTube stream active
- **Resource Usage**: CPU/Memory within limits

### Monitoring Tools
- **Windows Performance Counters**: CPU, memory, network
- **OBS Stats**: Stream health, dropped frames, bitrate
- **Custom Scripts**: SRT connection validation
- **YouTube API**: Stream status and viewer metrics

### Alerting Conditions
- **Process Failure**: OBS or ffmpeg crash
- **High Resource Usage**: CPU >80%, Memory >85%
- **Network Issues**: SRT disconnection, RTMP failure
- **Stream Quality**: High frame drops, audio desync

## Operational Procedures

### Startup Sequence
1. **System Boot**: Windows startup and service initialization
2. **Network Validation**: Verify SRT input connectivity
3. **OBS Launch**: Start OBS with saved scene configuration
4. **Stream Validation**: Confirm A/V and slide inputs
5. **YouTube Streaming**: Begin RTMP output to YouTube

### Shutdown Sequence
1. **Stop Streaming**: End RTMP output to YouTube
2. **Close OBS**: Graceful application shutdown
3. **Network Cleanup**: Close SRT connections
4. **System Shutdown**: Windows shutdown procedure

### Failure Recovery
- **Detection**: Process monitoring, health checks
- **Recovery**: Service restart, VM reboot if needed
- **Fallback**: Manual intervention, backup streaming
- **RTO**: 3 minutes maximum per mixer

## Testing Requirements

### Unit Tests
- **OBS Configuration**: Scene setup, audio mapping
- **SRT Connectivity**: Input stream reception
- **RTMP Output**: YouTube streaming functionality
- **Audio Processing**: Channel selection accuracy

### Integration Tests
- **End-to-End**: Full pipeline from relay to YouTube
- **Multi-Language**: All three mixers simultaneously
- **Failover**: Recovery from various failure scenarios
- **Performance**: Sustained streaming under load

### Load Tests
- **Duration**: 4+ hour continuous streaming
- **Quality**: Consistent output without degradation
- **Resource**: Monitor CPU/memory usage patterns
- **Network**: Bandwidth utilization and stability

## Maintenance Procedures

### Regular Maintenance
- **Windows Updates**: Monthly security patches
- **OBS Updates**: Quarterly application updates
- **Performance Review**: Weekly resource usage analysis
- **Configuration Backup**: Daily OBS scene exports

### Emergency Procedures
- **Stream Interruption**: Immediate restart protocols
- **Hardware Failure**: VM migration to backup host
- **Network Issues**: Alternative routing configuration
- **Software Corruption**: Restore from known good state

## Documentation and Training

### Operator Documentation
- **Quick Start Guide**: Stream startup procedures
- **Troubleshooting**: Common issues and solutions
- **Configuration Reference**: OBS settings and parameters
- **Emergency Contacts**: Support escalation procedures

### Technical Documentation
- **Architecture Diagrams**: Network and data flow
- **Configuration Files**: OBS scenes and settings
- **Monitoring Dashboards**: Performance metrics
- **Disaster Recovery**: Backup and restore procedures 