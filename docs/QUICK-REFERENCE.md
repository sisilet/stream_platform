# Quick Reference Card
## 🚨 Critical Information At-a-Glance

**Print this page and keep it handy during events!**

---

## ⏰ **Pre-Event Timeline (2 hours)**

| Time | Task | Duration |
|------|------|----------|
| T-2h | Environment check | 10m |
| T-90m | Deploy infrastructure | 25m |
| T-60m | Record IPs, test RDP | 10m |
| T-45m | Configure OBS | 15m |
| T-30m | Test connectivity | 10m |
| T-15m | Validate audio | 10m |
| T-10m | Pre-flight check | 5m |

## 🎬 **Go Live Sequence**

**⚡ CRITICAL: Follow this exact order!**

1. ✅ Start SRT input from local source
2. ✅ Enable streaming on Mixer 1 (Original) 
3. ⏸️ Wait 30 seconds
4. ✅ Enable streaming on Mixer 2 (Language A)
5. ⏸️ Wait 30 seconds 
6. ✅ Enable streaming on Mixer 3 (Language B)

**Verify all 3 YouTube streams show "LIVE" ✅**

---

## 🚨 **Alert Thresholds**

### 🔴 **IMMEDIATE ACTION REQUIRED**
- VM CPU > 90% | Dropped frames > 5% | FPS < 20
- YouTube stream offline | SRT connection lost

### 🟡 **WARNING - MONITOR CLOSELY**  
- VM CPU > 80% | Dropped frames > 1% | FPS < 25
- Network latency > 50ms | YouTube health "Good" or lower

---

## 🆘 **Emergency Actions**

### **Stream Drop (30 seconds)**
1. OBS → Settings → Stream → Reconnect
2. Monitor for 2 minutes
3. If failed: Restart OBS (desktop shortcut)

### **Complete Failure (5 minutes)**
1. Document current state (screenshots)
2. GitHub Actions → Deploy → New event name: `EVENT-NAME-EMERGENCY`
3. Local backup: `ffmpeg -i INPUT -f flv rtmp://BACKUP_KEY`

---

## 📝 **Record Deployment IPs**

```
Event Name: _________________________________
Resource Group: _____________________________

SRT Relay IP: _______________________________
Slide Splitter IP: ___________________________
Mixer 1 IP (Original): _______________________
Mixer 2 IP (Language A): ____________________
Mixer 3 IP (Language B): ____________________

YouTube Keys Configured: ✅ / ❌
Audio Channels Tested: ✅ / ❌
All RDP Connections: ✅ / ❌
```

---

## 📊 **Hourly Monitoring**

**OBS Health:**
```
Time: _______ 
Mixer 1: FPS ___/30  Dropped ___%  CPU ___%
Mixer 2: FPS ___/30  Dropped ___%  CPU ___%  
Mixer 3: FPS ___/30  Dropped ___%  CPU ___%
```

**YouTube Health:**
```
Stream 1: Health _______ Bitrate _______ Viewers _______
Stream 2: Health _______ Bitrate _______ Viewers _______
Stream 3: Health _______ Bitrate _______ Viewers _______
```

---

## 🧹 **Teardown (30 minutes)**

1. ✅ Stop streaming on all OBS instances (5m)
2. ✅ Save OBS logs from all VMs (5m)
3. ✅ GitHub Actions → Teardown → Event name (10m)
4. ✅ Verify Azure Portal shows $0 cost (5m)
5. ✅ Document lessons learned (5m)

---

## 📞 **Emergency Contacts**

| Role | Name | Phone |
|------|------|-------|
| Operations Lead | _________ | _________ |
| Technical Lead | _________ | _________ |
| Azure Support | _________ | _________ |

---

## 🔑 **Quick Access**

- **GitHub Actions:** `github.com/YOUR-ORG/YOUR-REPO/actions`
- **Azure Portal:** `portal.azure.com` 
- **YouTube Studio:** `studio.youtube.com`
- **VM Credentials:** `streamadmin` / `StreamAdmin2024!`

---

**🎯 Remember: Working backup > Perfect broken stream!** 