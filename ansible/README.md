# Ansible Orchestration for On-Demand Streaming System

This directory contains the Ansible infrastructure-as-code for deploying and managing the on-demand multilingual streaming system. **Each compute node type is managed in one comprehensive playbook.**

## 📁 Structure

```
ansible/
├── site.yml                           # Main orchestration playbook
├── playbooks/                         # Compute-type specific playbooks
│   ├── infrastructure.yml            # Azure infrastructure (networking, security)
│   ├── containers.yml                # Complete container management (deploy + configure + validate)
│   ├── virtual-machines.yml          # Complete VM management (deploy + configure + validate)
│   ├── local-environments.yml        # Local environment validation & remediation
│   └── teardown.yml                  # Resource cleanup
├── tasks/                            # Environment-specific task files
│   ├── obs-station-config.yml       # OBS station configuration
│   ├── audio-workstation-config.yml # Audio workstation setup
│   └── video-capture-config.yml     # Video capture configuration
├── templates/                        # Configuration templates
└── inventories/
    ├── production/
    │   └── hosts                     # Cloud deployment inventory
    └── local/
        └── hosts.ini                 # Local environment inventory

```

## 🏗️ **Compute-Node-Centric Design**

Each compute type is managed by a single comprehensive playbook:

### **📦 Containers** (`playbooks/containers.yml`)
- **Deploy**: SRT Relay + Slide Splitter (Azure Container Instances)
- **Configure**: Resource limits, environment variables, networking
- **Validate**: Health checks, port connectivity, container status

### **🖥️ Virtual Machines** (`playbooks/virtual-machines.yml`)
- **Deploy**: 3x Windows Server VMs with networking
- **Configure**: OBS Studio installation, audio settings, YouTube keys
- **Validate**: RDP connectivity, OBS validation, performance checks

### **🌐 Infrastructure** (`playbooks/infrastructure.yml`)
- **Deploy**: Resource groups, VNets, subnets, security groups
- **Foundation**: Required by both containers and VMs

### **🏠 Local Environments** (`playbooks/local-environments.yml`)
- **Validate**: Check software installations, versions, configurations
- **Remediate**: Install missing software, fix configurations
- **Support**: Windows, macOS, Linux across multiple environment types

## 🚀 Quick Start

### Deploy Complete Cloud System
```bash
# Full deployment (all compute types)
ansible-playbook -i inventories/production site.yml \
  --extra-vars "event_name=my-event youtube_keys=key1,key2,key3"

# With custom location
ansible-playbook -i inventories/production site.yml \
  --extra-vars "event_name=my-event azure_location='West US 2'"
```

### Manage Local Environments
```bash
# Validate and remediate all local environments
ansible-playbook -i inventories/local/hosts.ini site.yml --tags local

# Check specific environment type only
ansible-playbook -i inventories/local/hosts.ini site.yml --limit env_obs_station

# Validation only (no remediation)
ansible-playbook -i inventories/local/hosts.ini site.yml --tags local \
  --extra-vars "validation_mode=check_only"

# Force install/configure everything
ansible-playbook -i inventories/local/hosts.ini site.yml --tags local \
  --extra-vars "validation_mode=force_install"
```

### Manage Individual Compute Types
```bash
# Infrastructure only
ansible-playbook -i inventories/production site.yml --tags infrastructure

# Containers only (requires infrastructure)
ansible-playbook -i inventories/production site.yml --tags containers

# VMs only (requires infrastructure)
ansible-playbook -i inventories/production site.yml --tags vms
```

### Granular Control Within Compute Types
```bash
# Deploy containers only (skip configure/validate)
ansible-playbook -i inventories/production site.yml --tags containers --skip-tags configure,validate

# Configure VMs only (skip deploy/validate)
ansible-playbook -i inventories/production site.yml --tags vms --skip-tags deploy,validate

# Validate all compute types
ansible-playbook -i inventories/production site.yml --tags validate
```

### Teardown System
```bash
# Interactive teardown (with confirmation)
ansible-playbook -i inventories/production playbooks/teardown.yml \
  --extra-vars "event_name=my-event"

# Force teardown (no confirmation)
ansible-playbook -i inventories/production playbooks/teardown.yml \
  --extra-vars "event_name=my-event force_delete=true"
```

## 🏠 **Local Environment Management**

### **Environment Types Supported**

| Environment Type | Purpose | Supported OS | Key Software |
|------------------|---------|--------------|--------------|
| **OBS Station** | Live streaming operation | Windows, macOS | OBS Studio, VoiceMeeter, Audio drivers |
| **Audio Workstation** | Audio mixing/mastering | Windows, macOS, Linux | REAPER, Audacity, JACK, ASIO |
| **Video Capture** | Video processing/capture | macOS, Linux | FFmpeg, V4L2, capture tools |
| **Client Viewing** | Stream monitoring | Linux | VLC, browsers, monitoring tools |

### **Validation Modes**

```bash
# Check only - no changes made
validation_mode=check_only

# Check and fix - install missing, fix configs (default)
validation_mode=check_and_fix

# Force install - reinstall everything
validation_mode=force_install
```

### **Environment-Specific Features**

#### **🎬 OBS Station Configuration**
- **Windows**: OBS Studio, VoiceMeeter, audio optimization, firewall rules
- **macOS**: OBS via Homebrew, Core Audio configuration, BlackHole routing
- **Validation**: System requirements (4+ cores, 8GB+ RAM), streaming connectivity

#### **🎵 Audio Workstation Configuration**
- **Windows**: REAPER, ASIO4ALL, audio service optimization, MMCSS tuning
- **macOS**: Professional audio tools, Core Audio low-latency setup
- **Linux**: JACK audio system, real-time kernel configuration
- **Validation**: Professional requirements (4+ cores, 16GB+ RAM), audio hardware detection

#### **📹 Video Capture Configuration**
- **macOS**: FFmpeg, OBS, ImageMagick, camera detection
- **Linux**: V4L2 utilities, video device management
- **Validation**: High-performance requirements (8+ cores, 16GB+ RAM)

### **Local Inventory Management**

Edit `inventories/local/hosts.ini` to add your local machines:

```ini
[env_obs_station]
obs-station-01 ansible_host=192.168.1.10
obs-station-02 ansible_host=192.168.1.11

[env_audio_workstation]
audio-ws-01 ansible_host=192.168.1.20

[env_video_capture]
capture-01 ansible_host=192.168.1.30
```

### **Extending Local Environments**

To add new environment types:

1. **Add to inventory**: Create new `[env_your_type]` group
2. **Create task file**: `tasks/your-type-config.yml`
3. **Update playbook**: Add include in `local-environments.yml`
4. **Test**: Run validation on new environment type

## 🎯 **Compute Types Overview**

| Compute Type | Count | Purpose | Deployment | Configuration | Validation |
|--------------|-------|---------|------------|---------------|------------|
| **Containers** | 2 | SRT relay + slide conversion | Azure Container Instances | Resource limits, env vars | Health endpoints, connectivity |
| **Virtual Machines** | 3 | Language mixing with OBS | Windows Server 2022 | OBS Studio, audio mapping | RDP, OBS validation, performance |
| **Infrastructure** | 1 | Network foundation | VNet, subnets, NSGs | Security rules, IP ranges | Resource validation |
| **Local Environments** | Variable | Environment validation/remediation | Local machines | Software, configs, performance | Requirements, connectivity |

## ⚙️ Configuration

### Required Environment Variables
```bash
export AZURE_SUBSCRIPTION_ID="your-subscription-id"
export AZURE_TENANT_ID="your-tenant-id"
export AZURE_CLIENT_ID="your-client-id"
export AZURE_SECRET="your-client-secret"
```

### Compute-Specific Variables

**Container Configuration:**
```yaml
acr_name: streamingregistry001
relay_cpu: 2
relay_memory: 4
splitter_cpu: 1
splitter_memory: 2
```

**VM Configuration:**
```yaml
vm_admin_username: streamadmin
vm_admin_password: StreamAdmin2024!
vm_size: Standard_D2s_v3
youtube_keys: "key1,key2,key3"
```

### YouTube Configuration
```bash
# Deploy with YouTube keys
ansible-playbook site.yml \
  --extra-vars "youtube_keys=rtmp://a.rtmp.youtube.com/live2/key1,rtmp://a.rtmp.youtube.com/live2/key2,rtmp://a.rtmp.youtube.com/live2/key3"
```

## 🔍 Monitoring & Validation

### **Container Health Checks**
```bash
# SRT Relay health
curl http://{relay_ip}:8080/health

# Slide Splitter health  
curl http://{splitter_ip}:8080/health

# Container status
az container show --resource-group {rg} --name srt-relay-{event}
```

### **VM Health Checks**
```bash
# RDP connectivity
nc -zv 10.42.2.11 3389

# OBS validation (via PowerShell)
Test-Path "C:\Program Files\obs-studio\bin\64bit\obs64.exe"

# Performance check
Get-Counter "\Processor(_Total)\% Processor Time"
```

### **Network Connectivity**
```bash
# Test container to VM connectivity
Test-NetConnection -ComputerName 10.42.2.11 -Port 8001

# Test external RTMP (from VMs)
Test-NetConnection -ComputerName a.rtmp.youtube.com -Port 1935
```

## 🛠️ Troubleshooting by Compute Type

### **Container Issues**
```bash
# Check container logs
az container logs --resource-group {rg} --name srt-relay-{event}

# Restart container
az container restart --resource-group {rg} --name srt-relay-{event}

# Redeploy containers only
ansible-playbook site.yml --tags containers
```

### **VM Issues**
```bash
# Check VM status
az vm show --resource-group {rg} --name mixer-01-{event} --query provisioningState

# Connect via RDP
mstsc /v:{public_ip}:3389

# Reconfigure VMs only
ansible-playbook site.yml --tags vms --skip-tags deploy
```

### **Infrastructure Issues**
```bash
# Check networking
az network vnet show --resource-group {rg} --name streaming-vnet

# Validate security groups
az network nsg show --resource-group {rg} --name streaming-containers-nsg

# Redeploy infrastructure
ansible-playbook site.yml --tags infrastructure
```

## 💰 Cost Management by Compute Type

### **Resource Costs** (per 4-hour event)
- **Containers**: ~$2.40 (2x Standard ACI instances)
- **VMs**: ~$4.40 (3x Standard_D2s_v3 Windows VMs)
- **Infrastructure**: ~$0.10 (networking, public IPs)
- **Total**: ~$6.90

### **Cost Optimization**
```bash
# Deploy only containers (testing)
ansible-playbook site.yml --tags infrastructure,containers
# Cost: ~$2.50

# Deploy only VMs (OBS testing)
ansible-playbook site.yml --tags infrastructure,vms
# Cost: ~$4.50
```

## 🚨 Emergency Procedures by Compute Type

### **Container Recovery**
```bash
# Restart failed containers
az container restart --resource-group {rg} --name srt-relay-{event}
az container restart --resource-group {rg} --name slide-splitter-{event}

# Redeploy containers with new images
ansible-playbook site.yml --tags containers --extra-vars "force_redeploy=true"
```

### **VM Recovery** 
```bash
# Restart VMs
az vm restart --resource-group {rg} --name mixer-01-{event}

# Reconfigure OBS only
ansible-playbook site.yml --tags vms --tags configure --skip-tags deploy,validate
```

### **Complete Recovery**
```bash
# Emergency teardown and redeploy
ansible-playbook playbooks/teardown.yml --extra-vars "force_delete=true"
ansible-playbook site.yml --extra-vars "event_name=emergency-$(date +%s)"
```

## 📋 Maintenance by Compute Type

### **Container Maintenance**
- Update container images in ACR monthly
- Monitor container resource usage
- Test health endpoints regularly

### **VM Maintenance** 
- Update OBS Studio versions quarterly
- Rotate VM passwords monthly
- Monitor VM performance counters

### **Infrastructure Maintenance**
- Review network security rules
- Clean up old resource groups
- Update Ansible Azure collection

## 📚 Additional Resources

- [Azure Container Instances Documentation](https://docs.microsoft.com/en-us/azure/container-instances/)
- [Azure Virtual Machines Documentation](https://docs.microsoft.com/en-us/azure/virtual-machines/)
- [OBS Studio Documentation](https://obsproject.com/wiki/)
- [Ansible Azure Collection](https://docs.ansible.com/ansible/latest/collections/azure/azcollection/)
- [System Architecture Documentation](../docs/ARCHITECTURE.md)
- [On-Demand Orchestration Guide](../docs/ON-DEMAND-ORCHESTRATION.md) 