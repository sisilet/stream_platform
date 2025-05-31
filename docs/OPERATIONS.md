# Operations Guide
## Multilingual Streaming Platform

**Target Audience:** Event operations teams, stream operators  
**Event Type:** On-demand multilingual live streaming  
**Platform:** Azure + Ansible automation  

---

## 📋 Table of Contents

1. [Pre-Event Setup](#1-pre-event-setup)
2. [Event Day Operations](#2-event-day-operations)  
3. [Post-Event Teardown](#3-post-event-teardown)
4. [Troubleshooting](#4-troubleshooting)
5. [Emergency Procedures](#5-emergency-procedures)

---

## 1. Pre-Event Setup

### ⏰ Timeline: T-2 Hours Before Event

| Time | Task | Duration | Commands/Actions |
|------|------|----------|------------------|
| **T-2h** | **Environment Check** | 10m | Verify local machines, Azure login |
| **T-90m** | **Deploy Infrastructure** | 25m | GitHub Actions deployment |
| **T-60m** | **System Validation** | 10m | Record IPs, test RDP connections |
| **T-45m** | **Configure OBS** | 15m | Setup all 3 language mixers |
| **T-30m** | **Test Connectivity** | 10m | SRT & YouTube streaming tests |
| **T-15m** | **Audio Validation** | 10m | Verify 6-channel audio mapping |
| **T-10m** | **Pre-flight Check** | 5m | Final system verification |

### Step 1.1: Environment Check (T-2h)

**Local Environment Validation:**
```bash
# Verify all local machines are ready
ansible-playbook -i ansible/inventories/local/hosts.ini \
  ansible/playbooks/local-environments.yml \
  --extra-vars "validation_mode=check_only"

# If failures detected, run auto-fix:
ansible-playbook -i ansible/inventories/local/hosts.ini \
  ansible/playbooks/local-environments.yml \
  --extra-vars "validation_mode=check_and_fix"
```

**Azure Access Verification:**
```bash
# Verify Azure CLI login and permissions
az account show
az account list-locations --output table
```

### Step 1.2: Infrastructure Deployment (T-90m)

**🎯 GitHub Actions Deployment:**
1. Navigate to: `https://github.com/YOUR-ORG/YOUR-REPO/actions`
2. Select: **"Deploy Streaming Infrastructure"**
3. Click: **"Run workflow"**
4. Configure:
   ```yaml
   Event name: EVENT-NAME-YYYY-MM-DD
   Azure location: East US
   YouTube keys: rtmp://a.rtmp.youtube.com/live2/KEY1,KEY2,KEY3
   Deployment type: full
   ```

**Monitor Progress (20-25 minutes expected):**
- ✅ Infrastructure deployment: 5-7 minutes
- ✅ Container deployment: 2-3 minutes  
- ✅ VM deployment: 3-5 minutes
- ✅ Configuration: 2-3 minutes
- ✅ Health checks: 1-2 minutes

### Step 1.3: Record Deployment Information (T-60m)

**📝 Fill out connection details:**
```
Event Name: _________________________________
Resource Group: _____________________________
Deployment Time: ____________________________

SRT Relay IP: _______________________________
Slide Splitter IP: ___________________________
Mixer 1 IP (Original): _______________________
Mixer 2 IP (Language A): ____________________
Mixer 3 IP (Language B): ____________________
```

**🔍 Test RDP Connectivity:**
```bash
# Test each mixer VM (Windows VMs)
mstsc /v:MIXER-1-IP:3389
mstsc /v:MIXER-2-IP:3389  
mstsc /v:MIXER-3-IP:3389

# Credentials: streamadmin / StreamAdmin2024!
```

### Step 1.4: OBS Configuration (T-45m)

**On each mixer VM via RDP:**

1. **Launch OBS** using desktop shortcuts:
   - `Start-OBS-original.bat` (Mixer 1)
   - `Start-OBS-language-a.bat` (Mixer 2)
   - `Start-OBS-language-b.bat` (Mixer 3)

2. **Verify Configuration:**
   - ✅ Stream Key configured correctly
   - ✅ Audio input channels mapped
   - ✅ SRT source configured  
   - ✅ Output resolution: 1920x1080
   - ✅ Bitrate: 6000 kbps

### Step 1.5: Connectivity Testing (T-30m)

**Test SRT Connection:**
```bash
# Test from local capture machine to cloud relay
ffmpeg -re -i test-pattern.mp4 -c copy -f mpegts srt://SRT-RELAY-IP:9998
```

**Test YouTube Streaming:**
1. Start streaming from each OBS instance
2. Verify live streams appear on YouTube channels  
3. Stop test streams immediately

### Step 1.6: Audio Channel Validation (T-15m)

**Audio Channel Mapping:**
- **Mixer 1 (Original):** Channels 0,1 → Main presenter audio
- **Mixer 2 (Language A):** Channels 2,3 → Interpreter A audio
- **Mixer 3 (Language B):** Channels 4,5 → Interpreter B audio

**Test Multi-Channel Audio:**
```bash
# Send test audio with multiple channels
ffmpeg -f lavfi -i "sine=frequency=440:duration=10" \
       -f lavfi -i "sine=frequency=880:duration=10" \
       -filter_complex "[0:0][1:0]amerge=inputs=2[out]" \
       -map "[out]" -c:a aac -f mpegts srt://SRT-RELAY-IP:9998
```

---

## 2. Event Day Operations

### 🚨 Critical Go-Live Sequence (T-0)

**⚡ FOLLOW THIS EXACT ORDER:**

1. ✅ **Start SRT input** from local source
2. ✅ **Enable streaming** on Mixer 1 (Original)
3. ⏸️ **Wait 30 seconds** for stream stabilization
4. ✅ **Enable streaming** on Mixer 2 (Language A)  
5. ⏸️ **Wait 30 seconds**
6. ✅ **Enable streaming** on Mixer 3 (Language B)

**Final Verification:**
- [ ] All 3 YouTube streams showing "LIVE"
- [ ] Audio levels visible on all channels
- [ ] Video quality confirmed at 1080p
- [ ] No dropped frames in OBS (< 1%)

### 📊 Active Monitoring (Every 15 Minutes)

**OBS Health Check:**
```
Time: _______
Mixer 1: FPS ___/30  Dropped ___%  CPU ___%  Status: _____
Mixer 2: FPS ___/30  Dropped ___%  CPU ___%  Status: _____
Mixer 3: FPS ___/30  Dropped ___%  CPU ___%  Status: _____
```

**Network Health Check:**
```
SRT Relay: Latency ___ms  Packet Loss ___%
YouTube 1: Bitrate ___kbps  Health _______
YouTube 2: Bitrate ___kbps  Health _______  
YouTube 3: Bitrate ___kbps  Health _______
```

**🚨 Alert Thresholds:**
- **🔴 CRITICAL:** VM CPU > 90%, Dropped frames > 5%, FPS < 20
- **🟡 WARNING:** VM CPU > 80%, Dropped frames > 1%, FPS < 25

### 🎯 Real-Time Issue Response

**If stream drops:**
1. **OBS → Settings → Stream → Reconnect** (30 seconds)
2. **Monitor for 2 minutes** for recovery
3. **If not resolved:** See [Troubleshooting](#4-troubleshooting)

**If audio issues:**
1. **Check mixer levels** in OBS Audio panel
2. **Verify SRT input** stream connectivity
3. **Restart OBS** if needed (use desktop shortcut)

---

## 3. Post-Event Teardown

### 🧹 Safe Shutdown Sequence (T+30m)

**🎯 Follow This Exact Order:**

| Time | Task | Duration | Action |
|------|------|----------|--------|
| **T+5m** | **Stop Streaming** | 5m | Stop all OBS instances |
| **T+10m** | **Backup Data** | 5m | Save OBS logs and recordings |
| **T+15m** | **Teardown Infrastructure** | 10m | GitHub Actions teardown |
| **T+30m** | **Validate Cleanup** | 5m | Verify $0 Azure cost |

### Step 3.1: Stop Streaming (T+5m)

1. ✅ **Stop streaming** on all OBS instances
2. ✅ **Verify** YouTube streams show offline
3. ✅ **Close OBS** on all mixers
4. ✅ **Stop SRT input** from local source

### Step 3.2: Data Backup (T+10m)

**Save Event Data:**
```bash
# Download OBS logs from each VM
# Path: C:\Users\streamadmin\AppData\Roaming\obs-studio\logs\
```
- Export stream statistics  
- Save any recordings (if enabled)
- Document any issues encountered

### Step 3.3: Infrastructure Teardown (T+15m)

**🎯 GitHub Actions Teardown:**
1. Navigate to: `https://github.com/YOUR-ORG/YOUR-REPO/actions`
2. Select: **"Teardown Streaming Infrastructure"**
3. Click: **"Run workflow"**
4. Configure:
   ```yaml
   Event name: EVENT-NAME-YYYY-MM-DD
   Force delete: false
   Confirm teardown: CONFIRM
   ```

**Monitor Teardown (5-10 minutes expected):**
- Expected duration: 5-10 minutes
- Verify all resources deleted
- Confirm $0 ongoing cost

### Step 3.4: Final Validation (T+30m)

**Azure Portal Verification:**
1. Login to [Azure Portal](https://portal.azure.com)
2. Search for resource group: `streaming-EVENT-NAME-*`
3. Verify: **"No resources found"**
4. Check cost management: **"$0 current charges"**

---

## 4. Troubleshooting

### 🔧 Common Issues & Quick Fixes

#### **4.1 Deployment Issues**

**❌ GitHub Actions deployment fails:**
```
Error: AADSTS7000215: Invalid client secret
```
**✅ Solution:**
1. Check GitHub Secrets are correctly configured
2. Verify Azure service principal:
   ```bash
   az login --service-principal -u CLIENT_ID -p CLIENT_SECRET --tenant TENANT_ID
   ```
3. Regenerate service principal secret if expired

**❌ VM deployment timeout:**
```
Error: VM provisioning state: Failed
```
**✅ Solution:**
1. Check Azure quotas: Portal → Subscriptions → Usage + quotas
2. Try different Azure region
3. Reduce VM size if quota exceeded

#### **4.2 Connectivity Issues**

**❌ Can't RDP to VMs:**
**🔍 Diagnosis:**
```bash
nmap -p 3389 VM-PUBLIC-IP
telnet VM-PUBLIC-IP 3389
```
**✅ Solution:**
1. Check NSG rules in Azure Portal
2. Verify VM is running
3. Check Windows Firewall on VM

**❌ SRT connection fails:**
**🔍 Diagnosis:**
```bash
nc -uv SRT-RELAY-IP 9998
```
**✅ Solution:**
1. Check container status in Azure Portal
2. Verify container ports are exposed
3. Test with different SRT client

#### **4.3 Streaming Issues**

**❌ OBS won't start streaming:**
**✅ Solution:**
1. **Check stream key:** OBS → Settings → Stream → Show Key
2. **Test connectivity:** Settings → Stream → Test
3. **Reset settings:** Delete and recreate stream profile
4. **Restart OBS:** Use desktop shortcut

**❌ Poor video quality / dropped frames:**
**🔍 Check:** OBS Stats (View → Stats), CPU usage, network
**✅ Solutions:**
1. **Reduce bitrate:** OBS → Settings → Output → Bitrate (lower to 2000)
2. **Change encoder:** Settings → Output → Encoder (x264 → NVENC)
3. **Lower resolution:** Settings → Video → Output (720p)

**❌ Audio out of sync:**
**✅ Solution:**
1. **Restart audio:** OBS → Settings → Audio → Restart
2. **Adjust sync:** Sources → Audio → Advanced → Sync Offset
3. **Check sample rate:** Ensure 48kHz throughout pipeline

---

## 5. Emergency Procedures

### 🚨 Emergency Response by Severity

#### **🟢 Level 1 - Minor (5 minutes)**
- Single mixer issues
- Temporary network blips
- Audio quality reduction

**Response:**
1. Identify affected component
2. Attempt service restart
3. Monitor for recovery
4. Document issue

#### **🟡 Level 2 - Major (15 minutes)**  
- Multiple mixer failures
- SRT relay issues
- Significant quality degradation

**Response:**
1. Activate backup procedures
2. Redirect traffic to working components
3. Begin component replacement
4. Communicate with stakeholders

#### **🔴 Level 3 - Critical (30 minutes)**
- Complete streaming failure
- Unable to reach any resources
- YouTube streams offline

**Response:**
1. **Emergency redeployment** (new event name)
2. **Parallel troubleshooting**
3. **Stakeholder notification**
4. **Post-incident analysis**

### 🆘 Emergency Actions

**🚨 Complete System Failure:**
```bash
# 1. Document current state - take screenshots
# 2. Emergency redeployment with different event name
Event name: EVENT-NAME-EMERGENCY
Deployment type: full

# 3. Local backup streaming (bypass cloud)
ffmpeg -i local-source.mp4 -c:v libx264 -c:a aac \
  -f flv rtmp://a.rtmp.youtube.com/live2/BACKUP_KEY
```

**📞 Emergency Escalation:**
1. **0-5m:** Try self-recovery
2. **5-15m:** Call operations lead
3. **15-30m:** Escalate to technical lead  
4. **30m+:** Executive notification

### 📋 Emergency Contacts

| Role | Name | Phone | Email |
|------|------|-------|-------|
| **Operations Lead** | _________ | _________ | _________ |
| **Technical Lead** | _________ | _________ | _________ |
| **Azure Support** | _________ | _________ | _________ |

### 🔗 Critical URLs

- **GitHub Actions:** `github.com/YOUR-ORG/YOUR-REPO/actions`
- **Azure Portal:** [portal.azure.com](https://portal.azure.com)
- **YouTube Studio:** [studio.youtube.com](https://studio.youtube.com)

---

## 📝 Event Checklist

**Print this section and use during events:**

### Pre-Event Checklist
- [ ] Local environment validated
- [ ] Azure deployment completed
- [ ] All VMs accessible via RDP
- [ ] OBS configured on all mixers
- [ ] SRT connectivity tested
- [ ] YouTube streams tested
- [ ] Audio channels validated
- [ ] Backup procedures ready

### During Event Monitoring  
- [ ] All streams live and stable
- [ ] Monitoring dashboard active
- [ ] No critical alerts
- [ ] Audio/video quality good
- [ ] Viewer engagement normal

### Post-Event Cleanup
- [ ] Streams stopped gracefully
- [ ] Event data backed up
- [ ] Azure resources cleaned up
- [ ] Cost validated ($0)
- [ ] Documentation completed
- [ ] Lessons learned recorded

---

**🎯 Remember: It's better to have a working backup stream than a perfect broken stream!**

*Keep this guide accessible during all streaming events. Update emergency contacts before each event.* 