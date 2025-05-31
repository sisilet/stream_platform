# GitHub Actions CI/CD for Streaming System

This directory contains GitHub Actions workflows for automating the deployment and management of the on-demand multilingual streaming system.

## 🔄 **Workflows Overview**

| Workflow | Trigger | Purpose | Duration |
|----------|---------|---------|----------|
| [`validate-ansible.yml`](workflows/validate-ansible.yml) | Push/PR to `ansible/` | Validate Ansible code quality | ~3-5 min |
| [`build-containers.yml`](workflows/build-containers.yml) | Push/PR to `containers/` | Build & push container images | ~8-12 min |
| [`deploy-infrastructure.yml`](workflows/deploy-infrastructure.yml) | Manual dispatch | Deploy streaming infrastructure | ~15-25 min |
| [`teardown-infrastructure.yml`](workflows/teardown-infrastructure.yml) | Manual dispatch | Safely teardown resources | ~5-10 min |

## 🚀 **Quick Start**

### **1. Repository Setup**

Configure the required secrets in your GitHub repository:

```bash
# Azure Service Principal (required for infrastructure deployment)
AZURE_SUBSCRIPTION_ID     # Your Azure subscription ID
AZURE_TENANT_ID           # Azure tenant ID
AZURE_CLIENT_ID           # Service principal client ID
AZURE_SECRET              # Service principal client secret

# Combined Azure credentials for login action
AZURE_CREDENTIALS         # JSON object with all Azure credentials
```

### **2. Azure Credentials Format**

Create `AZURE_CREDENTIALS` secret with this JSON structure:

```json
{
  "clientId": "your-client-id",
  "clientSecret": "your-client-secret",
  "subscriptionId": "your-subscription-id",
  "tenantId": "your-tenant-id"
}
```

### **3. First Deployment**

1. Navigate to **Actions** tab in GitHub
2. Select **Deploy Streaming Infrastructure**
3. Click **Run workflow**
4. Fill in parameters:
   - **Event name**: `my-first-event`
   - **Azure location**: `East US`
   - **YouTube keys**: Your RTMP URLs (optional)
   - **Deployment type**: `full`

## 📋 **Workflow Details**

### **🔍 Validate Ansible** (`validate-ansible.yml`)

**Triggers:**
- Push to `main`/`develop` branches with `ansible/` changes
- Pull requests to `main` with `ansible/` changes
- Manual dispatch

**What it does:**
- ✅ Runs `ansible-lint` and `yamllint`
- ✅ Validates playbook syntax
- ✅ Checks inventory structure
- ✅ Validates project documentation
- ✅ Security scanning with Checkov
- ✅ Structure validation

**Example output:**
```
🎉 All validations passed!
✅ Ansible syntax and linting
✅ Security scanning
✅ Inventory validation
✅ Project structure
✅ Documentation

Ready for deployment! 🚀
```

### **📦 Build Containers** (`build-containers.yml`)

**Triggers:**
- Push to `main`/`develop` branches with `containers/` changes
- Pull requests to `main` with `containers/` changes
- Manual dispatch with force rebuild option

**What it does:**
- 🔍 Detects which containers changed
- 🏗️ Builds only changed containers (efficiency)
- 🔒 Multi-platform builds (linux/amd64, linux/arm64)
- 🛡️ Security scanning with Trivy
- 📦 Pushes to GitHub Container Registry
- 🔄 Auto-updates Ansible inventory with new image tags

**Supported containers:**
- `srt-relay` - SRT stream relay service
- `slide-splitter` - 32:9 to 16:9 conversion service

**Registry locations:**
```
ghcr.io/your-org/your-repo/srt-relay:latest
ghcr.io/your-org/your-repo/slide-splitter:latest
```

### **🚀 Deploy Infrastructure** (`deploy-infrastructure.yml`)

**Trigger:** Manual dispatch only (safety measure)

**Input parameters:**
- **Event name** (required): Unique identifier for this deployment
- **Azure location** (optional): Default `East US`
- **YouTube keys** (optional): Comma-separated RTMP URLs
- **Deployment type** (required): `full`, `infrastructure`, `containers`, or `vms`

**What it does:**
- ✅ Validates Ansible playbooks before deployment
- 🏗️ Deploys Azure infrastructure based on type
- 🔍 Runs post-deployment validation
- 📊 Provides Azure Portal links
- 💰 Shows cost estimates

**Deployment types:**
```bash
infrastructure  # Just networking, security groups
containers     # Infrastructure + containers only  
vms           # Infrastructure + VMs only
full          # Everything (containers + VMs)
```

**Example output:**
```
🚀 Deployment successful!
Event: my-webinar-2024
Resource Group: streaming-my-webinar-2024-1748475060
Azure Portal: https://portal.azure.com/#@/resource/...
Deployment Type: full
```

### **🗑️ Teardown Infrastructure** (`teardown-infrastructure.yml`)

**Trigger:** Manual dispatch only (safety measure)

**Input parameters:**
- **Event name** (required): Event to teardown (or `*` for all)
- **Force delete** (optional): Skip confirmation
- **Confirm teardown** (required): Must type `CONFIRM`

**Safety features:**
- 🛡️ Requires explicit confirmation
- 🔍 Shows resources before deletion
- 📊 Validates what will be deleted
- 💰 Shows cost savings

**What it does:**
- 🔍 Finds matching resource groups
- ⚠️ Shows what will be deleted
- 🗑️ Executes safe teardown
- 💰 Confirms cost savings

**Example output:**
```
🎉 Teardown completed successfully!
Event Pattern: my-webinar-2024
Resources Deleted: 1
Triggered by: username
💰 Monthly Savings: ~$200+ (estimated)
```

## 🔧 **Configuration**

### **Environment Variables**

All workflows use these environment variables:

```yaml
env:
  ANSIBLE_HOST_KEY_CHECKING: False
  AZURE_SUBSCRIPTION_ID: ${{ secrets.AZURE_SUBSCRIPTION_ID }}
  AZURE_TENANT_ID: ${{ secrets.AZURE_TENANT_ID }}
  AZURE_CLIENT_ID: ${{ secrets.AZURE_CLIENT_ID }}
  AZURE_SECRET: ${{ secrets.AZURE_SECRET }}
```

### **Workflow Permissions**

Required GitHub permissions:
- `contents: read` - Read repository contents
- `packages: write` - Push to GitHub Container Registry
- `security-events: write` - Upload security scan results
- `actions: read` - Access to Actions API

### **Customization**

#### **Add New Container**

1. Create `containers/your-container/Dockerfile`
2. Update `build-containers.yml` detection logic:
```yaml
if echo "$CHANGED_FILES" | grep -q "containers/your-container/"; then
  YOUR_CONTAINER_CHANGED="true"
fi
```

#### **Add New Azure Region**

Update default in `deploy-infrastructure.yml`:
```yaml
azure_location:
  description: 'Azure location'
  required: false
  default: 'West US 2'  # Change this
```

#### **Modify Resource Naming**

Edit Ansible playbooks:
```yaml
resource_group: "streaming-{{ event_name }}-{{ ansible_date_time.epoch }}"
```

## 🔍 **Monitoring & Troubleshooting**

### **Workflow Status**

Check workflow status:
1. Go to **Actions** tab
2. Select workflow run
3. Check job status and logs

### **Common Issues**

#### **Azure Authentication Failure**
```
Error: AADSTS7000215: Invalid client secret
```
**Solution:** Verify `AZURE_CREDENTIALS` secret is correct

#### **Ansible Lint Failures**
```
ansible-lint: Found X issue(s)
```
**Solution:** Run `ansible-lint ansible/` locally and fix issues

#### **Container Build Failures**
```
Error: failed to solve: dockerfile parse error
```
**Solution:** Check Dockerfile syntax in `containers/` directory

#### **Resource Group Already Exists**
```
The resource group 'streaming-event-123' already exists
```
**Solution:** Use different event name or teardown existing resources

### **Debugging Steps**

1. **Check workflow logs** in GitHub Actions
2. **Validate locally** with Ansible commands
3. **Test Azure credentials** with Azure CLI
4. **Check resource quotas** in Azure portal

## 📊 **Cost Management**

### **Estimated Costs per Workflow Run**

| Workflow | Azure Cost | GitHub Minutes | Total Cost |
|----------|------------|----------------|------------|
| Validate | $0 | ~5 minutes | ~$0.01 |
| Build Containers | $0 | ~12 minutes | ~$0.02 |
| Deploy Full | ~$6.90/4hrs | ~25 minutes | ~$6.95 |
| Teardown | $0 | ~10 minutes | ~$0.02 |

### **Cost Optimization**

- Use `infrastructure` deployment for testing
- Always teardown after events
- Use `containers` only for development
- Monitor with Azure Cost Management

## 🛡️ **Security**

### **Secret Management**
- All Azure credentials stored as GitHub secrets
- No secrets in code or logs
- Container registry uses GitHub token

### **Security Scanning**
- Ansible playbooks scanned with Checkov
- Container images scanned with Trivy
- Results uploaded to GitHub Security tab

### **Access Control**
- Manual dispatch only for deployments
- Confirmation required for teardowns
- Audit trail in GitHub Actions logs

## 📚 **Best Practices**

### **Development Workflow**

1. **Feature development:**
   ```bash
   # Create feature branch
   git checkout -b feature/new-container
   
   # Make changes to ansible/ or containers/
   # Push changes - triggers validation
   git push origin feature/new-container
   ```

2. **Testing deployment:**
   ```bash
   # Merge to main (triggers container builds)
   # Use GitHub Actions to deploy with test event name
   ```

3. **Production deployment:**
   ```bash
   # Use GitHub Actions with production event name
   # Monitor deployment in Azure portal
   ```

4. **Cleanup:**
   ```bash
   # Use teardown workflow with event name
   # Verify $0 cost in Azure portal
   ```

### **Naming Conventions**

- **Events**: `event-name-2024`, `webinar-january`, `conference-spring`
- **Resource Groups**: Auto-generated as `streaming-{event}-{timestamp}`
- **Container Tags**: Auto-generated as `{branch}-{commit-sha}`

### **Deployment Strategy**

- **Dev/Test**: Use `infrastructure` or `containers` only
- **Staging**: Use `full` with test event name
- **Production**: Use `full` with production event name
- **Emergency**: Use teardown with `force_delete=true`

This CI/CD setup provides a robust, secure, and cost-effective way to manage your streaming infrastructure! 🚀 