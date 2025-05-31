# On-Demand Streaming System Orchestration

**Version:** 3.1  
**Date:** 2025-01-27  
**Purpose:** Manual one-click setup and teardown for live streaming events

## Executive Summary

The streaming system is designed for **on-demand operation** with manual one-click deployment and teardown. This approach optimizes costs by only running infrastructure during live events and provides rapid deployment capabilities.

## Key Requirements

- ⚡ **Fast Setup**: Complete system ready in 10-15 minutes
- 💰 **Cost Optimization**: Zero costs when not streaming
- 🎯 **One-Click Operation**: Simple deployment and teardown
- 🔄 **Repeatable**: Consistent setup across events
- 📊 **Monitoring**: Real-time status during deployment
- 🛡️ **Reliable**: Automated rollback on failures

## Architecture Overview

```mermaid
graph TB
    subgraph "Control Plane"
        operator[Stream Operator]
        dashboard[Web Dashboard]
        cli[CLI Tool]
    end
    
    subgraph "Orchestration Layer"
        ansible[Ansible Playbooks]
        terraform[Terraform (Optional)]
        scripts[Deployment Scripts]
    end
    
    subgraph "Azure Resources (On-Demand)"
        rg[Resource Group]
        acr[Container Registry]
        aci1[SRT Relay Container]
        aci2[Slide Splitter Container]
        vm1[Language Mixer 1]
        vm2[Language Mixer 2]
        vm3[Language Mixer 3]
        vnet[Virtual Network]
        nsg[Network Security Groups]
    end
    
    operator --> dashboard
    operator --> cli
    dashboard --> ansible
    cli --> ansible
    ansible --> rg
    ansible --> acr
    ansible --> aci1
    ansible --> aci2
    ansible --> vm1
    ansible --> vm2
    ansible --> vm3
    ansible --> vnet
    ansible --> nsg
```

## One-Click Deployment Strategy

### Option 1: Web Dashboard (Recommended)
```html
<!-- Simple web interface -->
<div class="streaming-control">
    <h2>Live Streaming Event Control</h2>
    
    <div class="event-config">
        <input type="text" id="event-name" placeholder="Event Name">
        <select id="environment">
            <option value="production">Production</option>
            <option value="staging">Staging</option>
        </select>
        <input type="text" id="youtube-keys" placeholder="YouTube Stream Keys (3)">
    </div>
    
    <div class="controls">
        <button id="deploy-btn" class="deploy">🚀 Deploy System</button>
        <button id="status-btn" class="status">📊 Check Status</button>
        <button id="teardown-btn" class="teardown">🗑️ Teardown System</button>
    </div>
    
    <div id="deployment-status" class="status-panel">
        <!-- Real-time deployment progress -->
    </div>
</div>
```

### Option 2: CLI Tool
```bash
# Deploy system
./stream-control deploy --event "Conference-2025" --env production

# Check status
./stream-control status

# Teardown system
./stream-control teardown --confirm
```

### Option 3: Ansible Direct
```bash
# Deploy
ansible-playbook -i inventories/production deploy-streaming-system.yml \
  -e event_name="Conference-2025" \
  -e youtube_keys="key1,key2,key3"

# Teardown
ansible-playbook -i inventories/production teardown-streaming-system.yml
```

## Deployment Architecture

### Phase 1: Infrastructure Provisioning (5-7 minutes)
```yaml
# ansible/deploy-streaming-system.yml
---
- name: Deploy On-Demand Streaming Infrastructure
  hosts: localhost
  vars:
    event_name: "{{ event_name | default('streaming-event') }}"
    resource_group: "streaming-{{ event_name }}-{{ ansible_date_time.epoch }}"
    
  tasks:
    - name: Create Resource Group
      azure_rm_resourcegroup:
        name: "{{ resource_group }}"
        location: "{{ azure_location }}"
        tags:
          purpose: streaming
          event: "{{ event_name }}"
          created: "{{ ansible_date_time.iso8601 }}"
          auto_cleanup: "true"
    
    - name: Create Virtual Network
      azure_rm_virtualnetwork:
        name: "streaming-vnet"
        resource_group: "{{ resource_group }}"
        address_prefixes: "10.42.0.0/16"
        subnets:
          - name: containers
            address_prefix: "10.42.1.0/24"
          - name: mixers
            address_prefix: "10.42.2.0/24"
    
    - name: Create Network Security Groups
      azure_rm_securitygroup:
        name: "streaming-nsg"
        resource_group: "{{ resource_group }}"
        rules:
          - name: SRT-Inbound
            protocol: Udp
            destination_port_range: "9998-9999"
            access: Allow
            priority: 100
          - name: Health-Check
            protocol: Tcp
            destination_port_range: "8080"
            access: Allow
            priority: 101
```

### Phase 2: Container Deployment (2-3 minutes)
```yaml
- name: Deploy SRT Relay Container
  azure_rm_containerinstance:
    name: "srt-relay-{{ event_name }}"
    resource_group: "{{ resource_group }}"
    image: "{{ acr_name }}.azurecr.io/srt-relay:latest"
    cpu: 2
    memory: 4
    ports:
      - 9998
      - 8080
    environment_variables:
      MIXER1_IP: "10.42.2.11"
      MIXER2_IP: "10.42.2.12"
      MIXER3_IP: "10.42.2.13"
      EVENT_NAME: "{{ event_name }}"
    restart_policy: Always
    subnet_ids:
      - "{{ vnet_result.state.subnets[0].id }}"

- name: Deploy Slide Splitter Container
  azure_rm_containerinstance:
    name: "slide-splitter-{{ event_name }}"
    resource_group: "{{ resource_group }}"
    image: "{{ acr_name }}.azurecr.io/slide-splitter:latest"
    cpu: 1
    memory: 2
    ports:
      - 9999
      - 8080
    environment_variables:
      MIXER1_IP: "10.42.2.11"
      MIXER2_IP: "10.42.2.12"
      MIXER3_IP: "10.42.2.13"
      EVENT_NAME: "{{ event_name }}"
    restart_policy: Always
    subnet_ids:
      - "{{ vnet_result.state.subnets[0].id }}"
```

### Phase 3: Language Mixer VMs (3-5 minutes)
```yaml
- name: Create Language Mixer VMs
  azure_rm_virtualmachine:
    name: "mixer-{{ item.language }}-{{ event_name }}"
    resource_group: "{{ resource_group }}"
    vm_size: Standard_D2s_v3
    admin_username: streamadmin
    ssh_password_enabled: false
    ssh_public_keys:
      - path: /home/streamadmin/.ssh/authorized_keys
        key_data: "{{ ssh_public_key }}"
    image:
      offer: WindowsServer
      publisher: MicrosoftWindowsServer
      sku: 2022-Datacenter
      version: latest
    subnet_name: mixers
    virtual_network_name: streaming-vnet
    private_ip_allocation_method: Static
    private_ip_address: "{{ item.ip }}"
    tags:
      role: language-mixer
      language: "{{ item.language }}"
      event: "{{ event_name }}"
  loop:
    - { language: "original", ip: "10.42.2.11" }
    - { language: "spanish", ip: "10.42.2.12" }
    - { language: "french", ip: "10.42.2.13" }
  register: mixer_vms

- name: Configure OBS on Mixer VMs
  include_tasks: configure-obs-mixer.yml
  vars:
    mixer_vm: "{{ item }}"
    youtube_key: "{{ youtube_keys.split(',')[ansible_loop.index0] }}"
  loop: "{{ mixer_vms.results }}"
  loop_control:
    loop_var: item
```

## One-Click Control Scripts

### Master Control Script
```bash
#!/bin/bash
# stream-control.sh - Master control script for on-demand streaming

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ANSIBLE_DIR="$SCRIPT_DIR/ansible"
LOG_FILE="/tmp/stream-control-$(date +%Y%m%d-%H%M%S).log"

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

log_info() { echo -e "${BLUE}[INFO]${NC} $1" | tee -a "$LOG_FILE"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1" | tee -a "$LOG_FILE"; }
log_warning() { echo -e "${YELLOW}[WARNING]${NC} $1" | tee -a "$LOG_FILE"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1" | tee -a "$LOG_FILE"; }

# Deploy streaming system
deploy_system() {
    local event_name="$1"
    local environment="$2"
    local youtube_keys="$3"
    
    log_info "🚀 Starting deployment of streaming system..."
    log_info "Event: $event_name"
    log_info "Environment: $environment"
    log_info "Log file: $LOG_FILE"
    
    # Validate inputs
    if [[ -z "$event_name" || -z "$youtube_keys" ]]; then
        log_error "Event name and YouTube keys are required"
        exit 1
    fi
    
    # Check prerequisites
    check_prerequisites
    
    # Start deployment timer
    local start_time=$(date +%s)
    
    # Phase 1: Infrastructure
    log_info "📦 Phase 1: Deploying infrastructure..."
    ansible-playbook -i "$ANSIBLE_DIR/inventories/$environment" \
        "$ANSIBLE_DIR/deploy-streaming-system.yml" \
        -e "event_name=$event_name" \
        -e "youtube_keys=$youtube_keys" \
        -e "deployment_phase=infrastructure" \
        --tags infrastructure || {
        log_error "Infrastructure deployment failed"
        cleanup_failed_deployment "$event_name"
        exit 1
    }
    
    # Phase 2: Containers
    log_info "🐳 Phase 2: Deploying containers..."
    ansible-playbook -i "$ANSIBLE_DIR/inventories/$environment" \
        "$ANSIBLE_DIR/deploy-streaming-system.yml" \
        -e "event_name=$event_name" \
        -e "youtube_keys=$youtube_keys" \
        -e "deployment_phase=containers" \
        --tags containers || {
        log_error "Container deployment failed"
        cleanup_failed_deployment "$event_name"
        exit 1
    }
    
    # Phase 3: VMs and Configuration
    log_info "🖥️ Phase 3: Deploying and configuring VMs..."
    ansible-playbook -i "$ANSIBLE_DIR/inventories/$environment" \
        "$ANSIBLE_DIR/deploy-streaming-system.yml" \
        -e "event_name=$event_name" \
        -e "youtube_keys=$youtube_keys" \
        -e "deployment_phase=vms" \
        --tags vms || {
        log_error "VM deployment failed"
        cleanup_failed_deployment "$event_name"
        exit 1
    }
    
    # Phase 4: Health Checks
    log_info "🔍 Phase 4: Running health checks..."
    run_health_checks "$event_name" "$environment"
    
    # Calculate deployment time
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    
    log_success "✅ Deployment completed successfully!"
    log_info "⏱️ Total deployment time: ${duration}s"
    log_info "📊 System status: $(get_system_status "$event_name")"
    
    # Display connection information
    display_connection_info "$event_name" "$environment"
}

# Teardown streaming system
teardown_system() {
    local event_name="$1"
    local environment="$2"
    local confirm="$3"
    
    if [[ "$confirm" != "true" ]]; then
        echo "⚠️ This will destroy all resources for event: $event_name"
        read -p "Are you sure? (yes/no): " confirmation
        if [[ "$confirmation" != "yes" ]]; then
            log_info "Teardown cancelled"
            exit 0
        fi
    fi
    
    log_info "🗑️ Starting teardown of streaming system..."
    log_info "Event: $event_name"
    
    # Find resource groups for this event
    local resource_groups=$(az group list --query "[?tags.event=='$event_name'].name" -o tsv)
    
    if [[ -z "$resource_groups" ]]; then
        log_warning "No resource groups found for event: $event_name"
        exit 0
    fi
    
    # Teardown each resource group
    for rg in $resource_groups; do
        log_info "Deleting resource group: $rg"
        az group delete --name "$rg" --yes --no-wait
    done
    
    log_success "✅ Teardown initiated for all resources"
    log_info "🕐 Resources will be deleted in the background"
}

# Check system status
check_status() {
    local event_name="$1"
    local environment="$2"
    
    log_info "📊 Checking system status for event: $event_name"
    
    # Find resource groups
    local resource_groups=$(az group list --query "[?tags.event=='$event_name'].name" -o tsv)
    
    if [[ -z "$resource_groups" ]]; then
        log_warning "No active deployments found for event: $event_name"
        exit 0
    fi
    
    # Check each component
    for rg in $resource_groups; do
        log_info "Resource Group: $rg"
        
        # Check containers
        log_info "  Containers:"
        az container list --resource-group "$rg" --query "[].{Name:name,State:instanceView.state,IP:ipAddress.ip}" -o table
        
        # Check VMs
        log_info "  Virtual Machines:"
        az vm list --resource-group "$rg" --query "[].{Name:name,State:powerState,IP:privateIps[0]}" -o table
        
        # Check health endpoints
        check_health_endpoints "$rg"
    done
}

# Health check functions
run_health_checks() {
    local event_name="$1"
    local environment="$2"
    
    log_info "Running comprehensive health checks..."
    
    # Wait for containers to be ready
    wait_for_containers "$event_name"
    
    # Wait for VMs to be ready
    wait_for_vms "$event_name"
    
    # Test connectivity
    test_connectivity "$event_name"
    
    log_success "All health checks passed!"
}

wait_for_containers() {
    local event_name="$1"
    local max_attempts=30
    local attempt=1
    
    log_info "Waiting for containers to be ready..."
    
    while [[ $attempt -le $max_attempts ]]; do
        local ready_count=0
        local total_count=0
        
        # Check SRT Relay
        if curl -s -f "http://$(get_container_ip "srt-relay-$event_name"):8080" >/dev/null 2>&1; then
            ((ready_count++))
        fi
        ((total_count++))
        
        # Check Slide Splitter
        if curl -s -f "http://$(get_container_ip "slide-splitter-$event_name"):8080" >/dev/null 2>&1; then
            ((ready_count++))
        fi
        ((total_count++))
        
        if [[ $ready_count -eq $total_count ]]; then
            log_success "All containers are ready!"
            return 0
        fi
        
        log_info "Containers ready: $ready_count/$total_count (attempt $attempt/$max_attempts)"
        sleep 10
        ((attempt++))
    done
    
    log_error "Containers failed to become ready after $max_attempts attempts"
    return 1
}

# Display connection information
display_connection_info() {
    local event_name="$1"
    local environment="$2"
    
    echo ""
    log_success "🎉 Streaming System Ready!"
    echo ""
    echo "📡 Connection Information:"
    echo "  SRT Relay: srt://$(get_container_ip "srt-relay-$event_name"):9998"
    echo "  Slide Splitter: srt://$(get_container_ip "slide-splitter-$event_name"):9999"
    echo ""
    echo "🖥️ Language Mixers:"
    echo "  Original: http://$(get_vm_ip "mixer-original-$event_name"):3389 (RDP)"
    echo "  Spanish: http://$(get_vm_ip "mixer-spanish-$event_name"):3389 (RDP)"
    echo "  French: http://$(get_vm_ip "mixer-french-$event_name"):3389 (RDP)"
    echo ""
    echo "📊 Monitoring:"
    echo "  Health Checks: ./stream-control status --event $event_name"
    echo "  Logs: tail -f $LOG_FILE"
    echo ""
    echo "🗑️ Teardown:"
    echo "  ./stream-control teardown --event $event_name"
    echo ""
}

# Utility functions
get_container_ip() {
    local container_name="$1"
    az container show --name "$container_name" --resource-group "streaming-*" --query "ipAddress.ip" -o tsv 2>/dev/null || echo "N/A"
}

get_vm_ip() {
    local vm_name="$1"
    az vm show --name "$vm_name" --resource-group "streaming-*" --query "privateIps[0]" -o tsv 2>/dev/null || echo "N/A"
}

check_prerequisites() {
    log_info "Checking prerequisites..."
    
    # Check Azure CLI
    if ! command -v az &> /dev/null; then
        log_error "Azure CLI is not installed"
        exit 1
    fi
    
    # Check Ansible
    if ! command -v ansible-playbook &> /dev/null; then
        log_error "Ansible is not installed"
        exit 1
    fi
    
    # Check Azure login
    if ! az account show &> /dev/null; then
        log_error "Not logged in to Azure. Run 'az login' first."
        exit 1
    fi
    
    log_success "Prerequisites check passed"
}

# Main command dispatcher
main() {
    case "${1:-}" in
        deploy)
            shift
            local event_name=""
            local environment="production"
            local youtube_keys=""
            
            while [[ $# -gt 0 ]]; do
                case $1 in
                    --event)
                        event_name="$2"
                        shift 2
                        ;;
                    --env)
                        environment="$2"
                        shift 2
                        ;;
                    --youtube-keys)
                        youtube_keys="$2"
                        shift 2
                        ;;
                    *)
                        log_error "Unknown option: $1"
                        exit 1
                        ;;
                esac
            done
            
            deploy_system "$event_name" "$environment" "$youtube_keys"
            ;;
        teardown)
            shift
            local event_name=""
            local environment="production"
            local confirm="false"
            
            while [[ $# -gt 0 ]]; do
                case $1 in
                    --event)
                        event_name="$2"
                        shift 2
                        ;;
                    --env)
                        environment="$2"
                        shift 2
                        ;;
                    --confirm)
                        confirm="true"
                        shift
                        ;;
                    *)
                        log_error "Unknown option: $1"
                        exit 1
                        ;;
                esac
            done
            
            teardown_system "$event_name" "$environment" "$confirm"
            ;;
        status)
            shift
            local event_name=""
            local environment="production"
            
            while [[ $# -gt 0 ]]; do
                case $1 in
                    --event)
                        event_name="$2"
                        shift 2
                        ;;
                    --env)
                        environment="$2"
                        shift 2
                        ;;
                    *)
                        log_error "Unknown option: $1"
                        exit 1
                        ;;
                esac
            done
            
            check_status "$event_name" "$environment"
            ;;
        *)
            echo "Usage: $0 {deploy|teardown|status}"
            echo ""
            echo "Commands:"
            echo "  deploy   --event EVENT_NAME --youtube-keys KEY1,KEY2,KEY3 [--env ENV]"
            echo "  teardown --event EVENT_NAME [--env ENV] [--confirm]"
            echo "  status   --event EVENT_NAME [--env ENV]"
            echo ""
            echo "Examples:"
            echo "  $0 deploy --event 'Conference-2025' --youtube-keys 'key1,key2,key3'"
            echo "  $0 status --event 'Conference-2025'"
            echo "  $0 teardown --event 'Conference-2025' --confirm"
            exit 1
            ;;
    esac
}

# Run main function
main "$@"
```

## Web Dashboard Implementation

### Simple HTML Interface
```html
<!DOCTYPE html>
<html>
<head>
    <title>Streaming System Control</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 40px; }
        .container { max-width: 800px; margin: 0 auto; }
        .control-panel { background: #f5f5f5; padding: 20px; border-radius: 8px; margin: 20px 0; }
        .form-group { margin: 15px 0; }
        .form-group label { display: block; margin-bottom: 5px; font-weight: bold; }
        .form-group input, .form-group select { width: 100%; padding: 8px; border: 1px solid #ddd; border-radius: 4px; }
        .btn { padding: 12px 24px; margin: 5px; border: none; border-radius: 4px; cursor: pointer; font-size: 16px; }
        .btn-deploy { background: #28a745; color: white; }
        .btn-status { background: #17a2b8; color: white; }
        .btn-teardown { background: #dc3545; color: white; }
        .status-panel { background: #fff; border: 1px solid #ddd; padding: 20px; border-radius: 4px; margin: 20px 0; }
        .log-output { background: #000; color: #0f0; padding: 15px; border-radius: 4px; font-family: monospace; height: 300px; overflow-y: scroll; }
        .hidden { display: none; }
    </style>
</head>
<body>
    <div class="container">
        <h1>🎥 Streaming System Control Panel</h1>
        
        <div class="control-panel">
            <h2>Event Configuration</h2>
            
            <div class="form-group">
                <label for="event-name">Event Name:</label>
                <input type="text" id="event-name" placeholder="e.g., Conference-2025">
            </div>
            
            <div class="form-group">
                <label for="environment">Environment:</label>
                <select id="environment">
                    <option value="production">Production</option>
                    <option value="staging">Staging</option>
                    <option value="development">Development</option>
                </select>
            </div>
            
            <div class="form-group">
                <label for="youtube-keys">YouTube Stream Keys (comma-separated):</label>
                <input type="text" id="youtube-keys" placeholder="key1,key2,key3">
            </div>
            
            <div class="form-group">
                <button class="btn btn-deploy" onclick="deploySystem()">🚀 Deploy System</button>
                <button class="btn btn-status" onclick="checkStatus()">📊 Check Status</button>
                <button class="btn btn-teardown" onclick="teardownSystem()">🗑️ Teardown System</button>
            </div>
        </div>
        
        <div class="status-panel">
            <h3>System Status</h3>
            <div id="status-display">No active deployments</div>
        </div>
        
        <div class="status-panel">
            <h3>Deployment Log</h3>
            <div class="log-output" id="log-output">Ready for deployment...</div>
        </div>
    </div>

    <script>
        function deploySystem() {
            const eventName = document.getElementById('event-name').value;
            const environment = document.getElementById('environment').value;
            const youtubeKeys = document.getElementById('youtube-keys').value;
            
            if (!eventName || !youtubeKeys) {
                alert('Please fill in event name and YouTube keys');
                return;
            }
            
            logMessage('🚀 Starting deployment...');
            logMessage(`Event: ${eventName}`);
            logMessage(`Environment: ${environment}`);
            
            // Call backend API
            fetch('/api/deploy', {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({
                    eventName: eventName,
                    environment: environment,
                    youtubeKeys: youtubeKeys
                })
            })
            .then(response => response.json())
            .then(data => {
                if (data.success) {
                    logMessage('✅ Deployment started successfully');
                    pollDeploymentStatus(data.deploymentId);
                } else {
                    logMessage(`❌ Deployment failed: ${data.error}`);
                }
            })
            .catch(error => {
                logMessage(`❌ Error: ${error.message}`);
            });
        }
        
        function checkStatus() {
            const eventName = document.getElementById('event-name').value;
            if (!eventName) {
                alert('Please enter event name');
                return;
            }
            
            logMessage('📊 Checking system status...');
            
            fetch(`/api/status/${eventName}`)
            .then(response => response.json())
            .then(data => {
                updateStatusDisplay(data);
            })
            .catch(error => {
                logMessage(`❌ Error: ${error.message}`);
            });
        }
        
        function teardownSystem() {
            const eventName = document.getElementById('event-name').value;
            if (!eventName) {
                alert('Please enter event name');
                return;
            }
            
            if (!confirm(`Are you sure you want to teardown all resources for ${eventName}?`)) {
                return;
            }
            
            logMessage('🗑️ Starting teardown...');
            
            fetch('/api/teardown', {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({ eventName: eventName })
            })
            .then(response => response.json())
            .then(data => {
                if (data.success) {
                    logMessage('✅ Teardown initiated successfully');
                } else {
                    logMessage(`❌ Teardown failed: ${data.error}`);
                }
            })
            .catch(error => {
                logMessage(`❌ Error: ${error.message}`);
            });
        }
        
        function logMessage(message) {
            const logOutput = document.getElementById('log-output');
            const timestamp = new Date().toLocaleTimeString();
            logOutput.innerHTML += `[${timestamp}] ${message}\n`;
            logOutput.scrollTop = logOutput.scrollHeight;
        }
        
        function updateStatusDisplay(status) {
            const statusDisplay = document.getElementById('status-display');
            if (status.active) {
                statusDisplay.innerHTML = `
                    <strong>Active Deployment: ${status.eventName}</strong><br>
                    Containers: ${status.containers.length} running<br>
                    VMs: ${status.vms.length} running<br>
                    Health: ${status.health}<br>
                    <br>
                    <strong>Connection Info:</strong><br>
                    SRT Relay: srt://${status.srtRelayIP}:9998<br>
                    Slide Splitter: srt://${status.slideSplitterIP}:9999
                `;
            } else {
                statusDisplay.innerHTML = 'No active deployments';
            }
        }
        
        function pollDeploymentStatus(deploymentId) {
            const poll = setInterval(() => {
                fetch(`/api/deployment/${deploymentId}/status`)
                .then(response => response.json())
                .then(data => {
                    logMessage(data.message);
                    if (data.completed) {
                        clearInterval(poll);
                        if (data.success) {
                            logMessage('🎉 Deployment completed successfully!');
                            checkStatus();
                        } else {
                            logMessage('❌ Deployment failed');
                        }
                    }
                });
            }, 5000);
        }
    </script>
</body>
</html>
```

## Cost Optimization Features

### Resource Tagging for Auto-Cleanup
```yaml
# All resources tagged for automatic cleanup
tags:
  purpose: streaming
  event: "{{ event_name }}"
  created: "{{ ansible_date_time.iso8601 }}"
  auto_cleanup: "true"
  ttl: "24h"  # Auto-delete after 24 hours
```

### Scheduled Cleanup Job
```bash
#!/bin/bash
# cleanup-expired-resources.sh - Run as cron job

# Find resource groups older than 24 hours with auto_cleanup tag
az group list --query "[?tags.auto_cleanup=='true' && tags.created < '$(date -d '24 hours ago' -Iseconds)'].name" -o tsv | \
while read rg; do
    echo "Cleaning up expired resource group: $rg"
    az group delete --name "$rg" --yes --no-wait
done
```

## Deployment Time Optimization

### Pre-built VM Images
```yaml
# Use custom VM images with OBS pre-installed
- name: Create VM from custom image
  azure_rm_virtualmachine:
    name: "mixer-{{ item.language }}-{{ event_name }}"
    image:
      id: "/subscriptions/{{ subscription_id }}/resourceGroups/images/providers/Microsoft.Compute/images/streaming-mixer-v1.0"
    # Reduces deployment time from 10 minutes to 3 minutes
```

### Container Pre-warming
```bash
# Keep container registry warm with latest images
az acr run --registry $ACR_NAME --cmd "docker pull $ACR_NAME.azurecr.io/srt-relay:latest" /dev/null
az acr run --registry $ACR_NAME --cmd "docker pull $ACR_NAME.azurecr.io/slide-splitter:latest" /dev/null
```

## Monitoring and Alerting

### Real-time Deployment Monitoring
```python
# deployment-monitor.py - WebSocket server for real-time updates
import asyncio
import websockets
import json
import subprocess

async def deployment_monitor(websocket, path):
    async for message in websocket:
        data = json.loads(message)
        
        if data['action'] == 'deploy':
            # Start deployment process
            process = subprocess.Popen([
                './stream-control', 'deploy',
                '--event', data['eventName'],
                '--youtube-keys', data['youtubeKeys']
            ], stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)
            
            # Stream output to websocket
            for line in iter(process.stdout.readline, ''):
                await websocket.send(json.dumps({
                    'type': 'log',
                    'message': line.strip()
                }))
            
            # Send completion status
            await websocket.send(json.dumps({
                'type': 'complete',
                'success': process.returncode == 0
            }))

# Start WebSocket server
start_server = websockets.serve(deployment_monitor, "localhost", 8765)
asyncio.get_event_loop().run_until_complete(start_server)
asyncio.get_event_loop().run_forever()
```

## Summary

This on-demand orchestration system provides:

1. **⚡ Fast Deployment**: 10-15 minute complete system setup
2. **💰 Zero Idle Costs**: Resources only exist during events
3. **🎯 One-Click Operation**: Simple web dashboard or CLI
4. **🔄 Repeatable**: Consistent deployments across events
5. **📊 Real-time Monitoring**: Live deployment progress
6. **🛡️ Automatic Cleanup**: Prevents resource sprawl
7. **🎛️ Multiple Interfaces**: Web, CLI, and direct Ansible

The system is optimized for event-driven streaming with minimal operational overhead and maximum cost efficiency. 