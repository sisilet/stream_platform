# Orchestration Strategy for Multilingual Streaming System

**Version:** 3.1  
**Date:** 2025-01-27  
**Purpose:** Define the optimal orchestration approach for each system component

## Executive Summary

The streaming system uses a **hybrid orchestration approach** that leverages the strengths of different tools:

- **Ansible**: Infrastructure provisioning, VM configuration, secrets management
- **Azure DevOps + ACI**: Container build, test, and deployment
- **Custom Scripts**: Real-time stream operations and monitoring
- **Terraform** (optional): Infrastructure as Code for complex deployments

## Orchestration Matrix

| Component | Primary Tool | Secondary Tool | Rationale |
|-----------|-------------|----------------|-----------|
| **Infrastructure** | Ansible | Terraform | Configuration management strength |
| **Containers** | Azure DevOps + ACI | Ansible | Cloud-native orchestration |
| **VMs (Windows)** | Ansible | PowerShell DSC | Cross-platform automation |
| **Networking** | Ansible | Azure CLI | Declarative configuration |
| **Secrets** | Ansible Vault | Azure Key Vault | Centralized management |
| **Monitoring** | Ansible | Helm/Kubernetes | Agent deployment |
| **Stream Operations** | Custom Scripts | Ansible | Real-time requirements |

## Detailed Strategy

### 1. Infrastructure Layer (Ansible Primary)

**Use Ansible for:**
```yaml
# ansible/site.yml
---
- import_playbook: infrastructure.yml    # Resource groups, networks
- import_playbook: security.yml         # NSGs, firewalls, keys
- import_playbook: tailscale.yml        # VPN mesh setup
- import_playbook: monitoring.yml       # Prometheus, Grafana
```

**Benefits:**
- Idempotent infrastructure changes
- Version-controlled configuration
- Cross-cloud compatibility
- Rich Azure modules

**Example Structure:**
```
ansible/
├── inventories/
│   ├── production/
│   ├── staging/
│   └── development/
├── roles/
│   ├── azure-infrastructure/
│   ├── tailscale-mesh/
│   ├── windows-mixer/
│   └── monitoring/
├── playbooks/
│   ├── site.yml
│   ├── infrastructure.yml
│   └── deploy-mixers.yml
└── group_vars/
    ├── all.yml
    └── language_mixers.yml
```

### 2. Container Layer (Azure DevOps + ACI Primary)

**Use Azure DevOps for:**
- Automated container builds on code changes
- Security scanning with Trivy
- Multi-environment deployments
- Integration with Azure Container Registry

**Use ACI for:**
- Auto-restart on failure
- Built-in health monitoring
- Resource scaling
- Centralized logging

**Ansible Role (Supporting):**
```yaml
# roles/container-infrastructure/tasks/main.yml
- name: Create Container Registry
  azure_rm_containerregistry:
    name: "{{ acr_name }}"
    resource_group: "{{ resource_group }}"
    sku: Standard
    admin_enabled: true

- name: Configure ACI networking
  azure_rm_virtualnetwork:
    name: container-vnet
    resource_group: "{{ resource_group }}"
    address_prefixes: "10.42.0.0/16"
```

### 3. Language Mixer VMs (Ansible Primary)

**Ansible Strengths for Windows VMs:**
```yaml
# roles/windows-mixer/tasks/main.yml
- name: Install OBS Studio
  win_chocolatey:
    name: obs-studio
    version: "{{ obs_version }}"
    state: present

- name: Configure OBS scenes
  win_template:
    src: mixer-scene.json.j2
    dest: "{{ obs_config_path }}/scenes/{{ mixer_language }}.json"

- name: Create Windows Service for OBS
  win_service:
    name: "OBS-{{ mixer_language }}"
    path: "{{ obs_executable }}"
    start_mode: auto
    state: started

- name: Configure audio channel mapping
  win_template:
    src: audio-filters.json.j2
    dest: "{{ obs_config_path }}/filters/"
  vars:
    audio_channels: "{{ mixer_audio_mapping[mixer_language] }}"
```

### 4. Stream Operations (Custom Scripts Primary)

**Real-time Operations Script:**
```bash
#!/bin/bash
# stream-orchestrator.sh - Real-time stream management

start_streaming() {
    log_info "Starting streaming pipeline..."
    
    # 1. Verify infrastructure (Ansible-managed)
    ansible-playbook -i inventories/production verify-infrastructure.yml
    
    # 2. Start containers (ACI-managed)
    az container start --name srt-relay --resource-group streaming-rg
    az container start --name slide-splitter --resource-group streaming-rg
    
    # 3. Initialize mixers (Ansible-managed)
    ansible-playbook -i inventories/production start-mixers.yml
    
    # 4. Begin streaming (Custom logic)
    start_local_sources
    monitor_stream_health
}
```

## Implementation Phases

### Phase 1: Foundation (Ansible)
```bash
# Deploy base infrastructure
ansible-playbook -i inventories/production infrastructure.yml

# Configure networking and security
ansible-playbook -i inventories/production security.yml

# Set up Tailscale mesh
ansible-playbook -i inventories/production tailscale.yml
```

### Phase 2: Container Platform (Azure DevOps)
```bash
# Bootstrap CI/CD pipeline
./ci-cd/scripts/bootstrap-azure-devops.sh

# Deploy containers
az pipelines run --name "Build-All-Containers"
```

### Phase 3: VM Configuration (Ansible)
```bash
# Configure Windows language mixers
ansible-playbook -i inventories/production deploy-mixers.yml

# Install monitoring agents
ansible-playbook -i inventories/production monitoring.yml
```

### Phase 4: Operations (Custom Scripts)
```bash
# Real-time stream management
./scripts/stream-orchestrator.sh start
./scripts/stream-orchestrator.sh monitor
./scripts/stream-orchestrator.sh stop
```

## Tool Selection Criteria

### Use Ansible When:
- ✅ Configuring VMs (especially Windows)
- ✅ Managing infrastructure state
- ✅ Deploying across multiple environments
- ✅ Handling secrets and configuration
- ✅ Setting up monitoring agents

### Use Azure DevOps + ACI When:
- ✅ Building and deploying containers
- ✅ Automated testing and security scanning
- ✅ Managing container lifecycle
- ✅ Scaling based on demand
- ✅ Integration with Azure services

### Use Custom Scripts When:
- ✅ Real-time stream operations
- ✅ Complex conditional logic
- ✅ Performance-critical operations
- ✅ Integration with streaming APIs
- ✅ Event-driven automation

## Monitoring and Observability

### Ansible-Managed Components
```yaml
# roles/monitoring/tasks/main.yml
- name: Deploy Prometheus Node Exporter
  systemd:
    name: node_exporter
    enabled: yes
    state: started

- name: Configure Grafana dashboards
  uri:
    url: "http://{{ grafana_host }}:3000/api/dashboards/db"
    method: POST
    body_format: json
    body: "{{ lookup('file', 'dashboards/streaming-overview.json') }}"
```

### Container Monitoring (Azure Monitor)
- Built-in container insights
- Application performance monitoring
- Log analytics integration
- Custom metrics collection

### Stream Health Monitoring (Custom)
```bash
# monitor-streams.sh
check_stream_health() {
    # Check SRT connections
    # Verify YouTube RTMP status
    # Monitor audio/video sync
    # Alert on failures
}
```

## Disaster Recovery Strategy

### Infrastructure Recovery (Ansible)
```yaml
# disaster-recovery.yml
- name: Restore from backup region
  include_tasks: restore-infrastructure.yml
  when: primary_region_failed

- name: Reconfigure networking
  include_tasks: setup-networking.yml

- name: Restore VM configurations
  include_tasks: restore-vms.yml
```

### Container Recovery (ACI + Azure DevOps)
- Automatic restart policies
- Multi-region container deployment
- Blue-green deployment capability
- Rollback to previous versions

### Data Recovery (Custom Scripts)
```bash
# restore-streaming-config.sh
restore_obs_scenes() {
    ansible-playbook restore-obs-config.yml
}

restore_stream_keys() {
    ansible-vault decrypt secrets.yml
    # Restore YouTube RTMP keys
}
```

## Security Considerations

### Ansible Security
- Ansible Vault for secrets
- SSH key management
- Role-based access control
- Audit logging

### Container Security
- Image vulnerability scanning
- Runtime security policies
- Network segmentation
- Secrets management via Azure Key Vault

### Operational Security
- Encrypted communication channels
- Multi-factor authentication
- Principle of least privilege
- Regular security updates

## Cost Optimization

### Ansible Benefits
- Reduced manual configuration time
- Consistent environments reduce debugging
- Automated scaling based on schedules

### Container Benefits
- Pay-per-use pricing model
- Automatic resource optimization
- No idle VM costs

### Hybrid Benefits
- Use appropriate tool for each task
- Minimize operational overhead
- Optimize for both cost and performance

## Conclusion

The hybrid orchestration approach provides:

1. **Ansible** handles infrastructure and VM configuration where it excels
2. **Azure DevOps + ACI** manages containers with cloud-native capabilities
3. **Custom scripts** handle real-time streaming operations
4. **Clear separation of concerns** between tools
5. **Optimal tool selection** for each specific task

This strategy leverages the strengths of each tool while avoiding their weaknesses, resulting in a more maintainable and efficient streaming system. 