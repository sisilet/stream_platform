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
    if ! ansible-playbook -i "$ANSIBLE_DIR/inventories/$environment" \
        "$ANSIBLE_DIR/deploy-streaming-system.yml" \
        -e "event_name=$event_name" \
        -e "youtube_keys=$youtube_keys" \
        -e "deployment_phase=infrastructure" \
        --tags infrastructure; then
        log_error "Infrastructure deployment failed"
        cleanup_failed_deployment "$event_name"
        exit 1
    fi
    
    # Phase 2: Containers
    log_info "🐳 Phase 2: Deploying containers..."
    if ! ansible-playbook -i "$ANSIBLE_DIR/inventories/$environment" \
        "$ANSIBLE_DIR/deploy-streaming-system.yml" \
        -e "event_name=$event_name" \
        -e "youtube_keys=$youtube_keys" \
        -e "deployment_phase=containers" \
        --tags containers; then
        log_error "Container deployment failed"
        cleanup_failed_deployment "$event_name"
        exit 1
    fi
    
    # Phase 3: VMs and Configuration
    log_info "🖥️ Phase 3: Deploying and configuring VMs..."
    if ! ansible-playbook -i "$ANSIBLE_DIR/inventories/$environment" \
        "$ANSIBLE_DIR/deploy-streaming-system.yml" \
        -e "event_name=$event_name" \
        -e "youtube_keys=$youtube_keys" \
        -e "deployment_phase=vms" \
        --tags vms; then
        log_error "VM deployment failed"
        cleanup_failed_deployment "$event_name"
        exit 1
    fi
    
    # Phase 4: Health Checks
    log_info "🔍 Phase 4: Running health checks..."
    run_health_checks "$event_name" "$environment"
    
    # Calculate deployment time
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    
    log_success "✅ Deployment completed successfully!"
    log_info "⏱️ Total deployment time: ${duration}s"
    
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
    local resource_groups
    resource_groups=$(az group list --query "[?tags.event=='$event_name'].name" -o tsv 2>/dev/null || echo "")
    
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
    local resource_groups
    resource_groups=$(az group list --query "[?tags.event=='$event_name'].name" -o tsv 2>/dev/null || echo "")
    
    if [[ -z "$resource_groups" ]]; then
        log_warning "No active deployments found for event: $event_name"
        exit 0
    fi
    
    # Check each component
    for rg in $resource_groups; do
        log_info "Resource Group: $rg"
        
        # Check containers
        log_info "  Containers:"
        az container list --resource-group "$rg" --query "[].{Name:name,State:instanceView.state,IP:ipAddress.ip}" -o table 2>/dev/null || echo "    No containers found"
        
        # Check VMs
        log_info "  Virtual Machines:"
        az vm list --resource-group "$rg" --query "[].{Name:name,State:powerState,IP:privateIps[0]}" -o table 2>/dev/null || echo "    No VMs found"
        
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
        local relay_ip
        relay_ip=$(get_container_ip "srt-relay-$event_name")
        if [[ "$relay_ip" != "N/A" ]] && curl -s -f "http://$relay_ip:8080" >/dev/null 2>&1; then
            ((ready_count++))
        fi
        ((total_count++))
        
        # Check Slide Splitter
        local splitter_ip
        splitter_ip=$(get_container_ip "slide-splitter-$event_name")
        if [[ "$splitter_ip" != "N/A" ]] && curl -s -f "http://$splitter_ip:8080" >/dev/null 2>&1; then
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

wait_for_vms() {
    local event_name="$1"
    local max_attempts=20
    local attempt=1
    
    log_info "Waiting for VMs to be ready..."
    
    while [[ $attempt -le $max_attempts ]]; do
        local ready_count=0
        local total_count=0
        
        # Check each mixer VM
        for lang in original spanish french; do
            local vm_status
            vm_status=$(az vm get-instance-view --name "mixer-$lang-$event_name" --resource-group "streaming-$event_name-*" --query "instanceView.statuses[1].displayStatus" -o tsv 2>/dev/null || echo "Unknown")
            if [[ "$vm_status" == "VM running" ]]; then
                ((ready_count++))
            fi
            ((total_count++))
        done
        
        if [[ $ready_count -eq $total_count ]]; then
            log_success "All VMs are ready!"
            return 0
        fi
        
        log_info "VMs ready: $ready_count/$total_count (attempt $attempt/$max_attempts)"
        sleep 15
        ((attempt++))
    done
    
    log_warning "Some VMs may not be fully ready, but continuing..."
    return 0
}

test_connectivity() {
    local event_name="$1"
    
    log_info "Testing network connectivity..."
    
    # Test SRT ports
    local relay_ip
    relay_ip=$(get_container_ip "srt-relay-$event_name")
    if [[ "$relay_ip" != "N/A" ]]; then
        if nc -z -w5 "$relay_ip" 9998 2>/dev/null; then
            log_success "SRT Relay port 9998 is accessible"
        else
            log_warning "SRT Relay port 9998 is not accessible"
        fi
    fi
    
    local splitter_ip
    splitter_ip=$(get_container_ip "slide-splitter-$event_name")
    if [[ "$splitter_ip" != "N/A" ]]; then
        if nc -z -w5 "$splitter_ip" 9999 2>/dev/null; then
            log_success "Slide Splitter port 9999 is accessible"
        else
            log_warning "Slide Splitter port 9999 is not accessible"
        fi
    fi
}

check_health_endpoints() {
    local resource_group="$1"
    
    log_info "  Health Endpoints:"
    
    # Check container health endpoints
    local containers
    containers=$(az container list --resource-group "$resource_group" --query "[].name" -o tsv 2>/dev/null || echo "")
    
    for container in $containers; do
        local ip
        ip=$(az container show --name "$container" --resource-group "$resource_group" --query "ipAddress.ip" -o tsv 2>/dev/null || echo "N/A")
        if [[ "$ip" != "N/A" ]]; then
            if curl -s -f "http://$ip:8080" >/dev/null 2>&1; then
                echo "    $container: ✅ Healthy"
            else
                echo "    $container: ❌ Unhealthy"
            fi
        else
            echo "    $container: ⚠️ No IP assigned"
        fi
    done
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
    echo "  Original: $(get_vm_ip "mixer-original-$event_name") (RDP: 3389)"
    echo "  Spanish: $(get_vm_ip "mixer-spanish-$event_name") (RDP: 3389)"
    echo "  French: $(get_vm_ip "mixer-french-$event_name") (RDP: 3389)"
    echo ""
    echo "📊 Monitoring:"
    echo "  Health Checks: ./stream-control.sh status --event $event_name"
    echo "  Logs: tail -f $LOG_FILE"
    echo ""
    echo "🗑️ Teardown:"
    echo "  ./stream-control.sh teardown --event $event_name"
    echo ""
}

# Utility functions
get_container_ip() {
    local container_name="$1"
    local resource_groups
    resource_groups=$(az group list --query "[?contains(name, 'streaming')].name" -o tsv 2>/dev/null || echo "")
    
    for rg in $resource_groups; do
        local ip
        ip=$(az container show --name "$container_name" --resource-group "$rg" --query "ipAddress.ip" -o tsv 2>/dev/null || echo "")
        if [[ -n "$ip" ]]; then
            echo "$ip"
            return
        fi
    done
    echo "N/A"
}

get_vm_ip() {
    local vm_name="$1"
    local resource_groups
    resource_groups=$(az group list --query "[?contains(name, 'streaming')].name" -o tsv 2>/dev/null || echo "")
    
    for rg in $resource_groups; do
        local ip
        ip=$(az vm show --name "$vm_name" --resource-group "$rg" --query "privateIps[0]" -o tsv 2>/dev/null || echo "")
        if [[ -n "$ip" ]]; then
            echo "$ip"
            return
        fi
    done
    echo "N/A"
}

cleanup_failed_deployment() {
    local event_name="$1"
    
    log_warning "Cleaning up failed deployment..."
    
    local resource_groups
    resource_groups=$(az group list --query "[?tags.event=='$event_name'].name" -o tsv 2>/dev/null || echo "")
    
    for rg in $resource_groups; do
        log_info "Cleaning up resource group: $rg"
        az group delete --name "$rg" --yes --no-wait
    done
}

check_prerequisites() {
    log_info "Checking prerequisites..."
    
    # Check Azure CLI
    if ! command -v az &> /dev/null; then
        log_error "Azure CLI is not installed"
        log_error "Install with: curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash"
        exit 1
    fi
    
    # Check Ansible
    if ! command -v ansible-playbook &> /dev/null; then
        log_error "Ansible is not installed"
        log_error "Install with: pip install ansible"
        exit 1
    fi
    
    # Check Azure login
    if ! az account show &> /dev/null; then
        log_error "Not logged in to Azure. Run 'az login' first."
        exit 1
    fi
    
    # Check netcat for connectivity tests
    if ! command -v nc &> /dev/null; then
        log_warning "netcat not found, skipping connectivity tests"
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
            echo "🎥 Streaming System Control"
            echo ""
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
            echo ""
            echo "Environments: production, staging, development"
            exit 1
            ;;
    esac
}

# Run main function
main "$@" 