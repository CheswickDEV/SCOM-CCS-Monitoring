# 🛡️ SCOM Central Certificate Store Monitoring

### A SCOM Management Pack that discovers and monitors SSL/TLS certificates in the Windows Central Certificate Store — with automatic expiration alerts and issuer filtering.

[![GitHub Stars](https://img.shields.io/github/stars/CheswickDEV/SCOM-CCS-Monitoring?color=00d4ff&labelColor=16161f)](https://github.com/CheswickDEV/SCOM-CCS-Monitoring)
[![Last Commit](https://img.shields.io/github/last-commit/CheswickDEV/SCOM-CCS-Monitoring?color=a855f7&labelColor=16161f)](https://github.com/CheswickDEV/SCOM-CCS-Monitoring/commits/main)
![Version](https://img.shields.io/badge/version-1.0.0.0-00d4ff?labelColor=16161f)
![Status](https://img.shields.io/badge/status-Active-00d4ff?labelColor=16161f)
![License](https://img.shields.io/badge/license-MIT-a855f7?labelColor=16161f)
![PowerShell](https://img.shields.io/badge/PowerShell-4.0+-a855f7?logo=powershell&logoColor=white&labelColor=16161f)
![SCOM](https://img.shields.io/badge/SCOM-2012_R2+-a855f7?labelColor=16161f)

---

## 💡 What It Does

Managing SSL/TLS certificates across servers is tedious and forgetting to renew one can cause outages. This Management Pack automates the entire monitoring lifecycle:

1. **Discovers** the Central Certificate Store (CCS) on any Windows Server where it's configured
2. **Inventories** all PFX certificates within the store
3. **Monitors** expiration dates and raises alerts when certificates are about to expire
4. **Filters** out irrelevant certificates (e.g. internal test CAs) via configurable issuer exclusions

No agents to deploy, no scripts to schedule — it runs inside SCOM like any other Management Pack.

---

## 📋 Table of Contents

- [Features](#-features)
- [Requirements](#-requirements)
- [Quick Start](#-quick-start)
- [Configuration](#️-configuration)
- [Monitoring Details](#-monitoring-details)
- [Troubleshooting](#-troubleshooting)
- [Event ID Reference](#-event-id-reference)
- [Best Practices](#-best-practices)
- [Security](#-security)
- [Tech Stack](#️-tech-stack)
- [Changelog](#-changelog)
- [License](#-license)

---

## ⚡ Features

- **🔍 Automatic Discovery** — Detects the Central Certificate Store and all certificates within it by reading the IIS CCS registry configuration.

- **⏰ Expiration Monitoring** — Raises a Warning alert when certificates are within 24 hours of expiring (configurable). Automatically resolves when renewed.

- **🏷️ Issuer Filtering** — Exclude certificates from specific CAs (e.g. internal test issuers) to reduce alert noise. Supports partial matching with wildcards.

- **📊 Detailed Alerts** — Each alert includes subject, expiration date/time, issuer information, and hours until expiration.

- **⚙️ Fully Configurable** — Override warning thresholds, discovery intervals, and monitoring intervals via standard SCOM overrides.

---

## 📋 Requirements

- System Center Operations Manager 2012 R2 or later
- Windows Server 2012+ with IIS Central Certificate Store configured
- PowerShell 4.0 or later on monitored servers
- SCOM agent service account with read access to the CCS path

---

## 🚀 Quick Start

### 1. Import the Management Pack

```powershell
Import-SCOMManagementPack -FullName "CentralCertificateStore.MP.xml"
```

### 2. Wait for Discovery

- CCS discovery runs every **4 hours**
- Certificate discovery runs every **1 hour**
- First alerts appear after the initial certificate discovery cycle

### 3. Configure Issuer Filtering (optional)

If you need to exclude internal test CAs, see [Excluding Certificates by Issuer](#excluding-certificates-by-issuer) below.

---

## ⚙️ Configuration

### Excluding Certificates by Issuer

1. In SCOM Console → **Authoring** → **Management Pack Objects** → **Object Discoveries**
2. Find **Certificate Discovery** (`CentralCertificateStore.MP.Certificate.Discovery`)
3. Right-click → **Overrides** → **Override the Discovery** → **For all objects of class: Central Certificate Store**
4. Set **ExcludedIssuers** with a semicolon-separated list:
   ```
   CN=Internal Test CA;CN=Dev Certificate Authority;O=Test Organization
   ```
5. Save the override to an appropriate Management Pack

### Adjusting Warning Threshold

The default threshold is **24 hours** before expiration. To change it:

1. **Authoring** → **Monitors** → Find **Certificate Expiration Monitor**
2. Override **WarningThresholdHours** (e.g. `48` for 2 days, `168` for 1 week)

### Adjusting Intervals

| Component | Default | Override Parameter |
|:----------|:-------:|:-------------------|
| CCS Discovery | 4 hours | `IntervalSeconds` (e.g. `7200` for 2h) |
| Certificate Discovery | 1 hour | `IntervalSeconds` |
| Expiration Monitor | 1 hour | `IntervalSeconds` |

---

## 📊 Monitoring Details

### Discovery Process

**Central Certificate Store Discovery** (every 4 hours):
- Runs on all Windows Server Operating Systems
- Checks registry path `HKLM:\SOFTWARE\Microsoft\IIS\CentralCertProvider`
- Requires `Enabled = 1` and a valid `CertStoreLocation` path
- Creates one CCS instance per server

**Certificate Discovery** (every 1 hour):
- Reads all PFX files from the configured CCS path
- Filters out certificates matching excluded issuers
- Extracts: Thumbprint, Subject, Issuer, Valid From, Valid Until, Friendly Name

### Health States

| State | Condition |
|:------|:----------|
| 🟢 **Healthy** | Certificate is valid and not within warning threshold |
| 🟡 **Warning** | Certificate will expire within the configured threshold |
| 🔴 **Critical** | Certificate has already expired |

Alerts auto-resolve when the certificate is renewed or the expiration window extends beyond the threshold.

---

## 🔧 Troubleshooting

### Certificates Not Discovered

1. Verify CCS is configured:
   ```powershell
   Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\IIS\CentralCertProvider"
   ```
2. Confirm `Enabled = 1` and `CertStoreLocation` points to an accessible path
3. Verify PFX files exist in the configured path
4. Check SCOM event logs for script errors (Event IDs 2000–2006)

### Certificates Discovered But Not Monitored

1. Check SCOM event logs for monitoring script errors (Event IDs 3000–3006)
2. Verify certificate files are not corrupted
3. Confirm password-protected PFX files have the correct password in registry

### Issuer Filtering Not Working

1. Verify the override is saved and applied
2. Check that issuer names match exactly (partial matching with wildcards is supported)
3. Use semicolons (`;`) as separators — not commas
4. Wait for the next discovery cycle (1 hour) or trigger discovery manually

### Viewing Event Logs

```powershell
# Discovery events
Get-EventLog -LogName "Operations Manager" -Source "Health Service Script" |
    Where-Object { $_.Message -like "*Discover-Central*" } |
    Select-Object TimeGenerated, EntryType, Message

# Monitoring events
Get-EventLog -LogName "Operations Manager" -Source "Health Service Script" |
    Where-Object { $_.Message -like "*Monitor-Certificate*" } |
    Select-Object TimeGenerated, EntryType, Message
```

---

## 📋 Event ID Reference

<details>
<summary><strong>Discovery Events</strong></summary>

| Event ID | Meaning |
|:--------:|:--------|
| 1000 | Central Certificate Store discovered successfully |
| 1001 | Central Certificate Store not enabled |
| 1002 | Registry key not found |
| 1003 | Error during CCS discovery |
| 2000 | Certificates discovered successfully |
| 2001–2006 | Various certificate discovery errors/warnings |

</details>

<details>
<summary><strong>Monitoring Events</strong></summary>

| Event ID | Meaning |
|:--------:|:--------|
| 3000 | Certificate is healthy |
| 3003 | Certificate has expired (Critical) |
| 3004 | Certificate expiring soon (Warning) |
| 3005 | Certificate not found |
| 3006 | Monitoring error |

</details>

---

## 🏆 Best Practices

1. **Set thresholds that match your renewal process** — if certificate renewal takes a week, set the threshold to at least 168 hours
2. **Exclude test CAs** — reduce alert noise by filtering out internal and development certificate authorities
3. **Configure alert routing** — set up SCOM notification subscriptions to email or Teams for certificate alerts
4. **Test with expiring certs** — periodically verify monitoring works by deploying a certificate that expires within the threshold
5. **Integrate with renewal automation** — if you use ACME/Let's Encrypt or internal CA automation, alerts should auto-resolve after renewal

---

## 🔒 Security

- The Management Pack reads certificates with **read-only** access — no private keys are extracted
- PFX passwords stored in registry should use encrypted storage where possible
- SCOM agent service account requires read access to the CCS path
- Consider restricting access to override Management Packs containing issuer filter configurations

---

## 🛠️ Tech Stack

![PowerShell](https://img.shields.io/badge/PowerShell-16161f?logo=powershell&logoColor=00d4ff)
![SCOM](https://img.shields.io/badge/SCOM-16161f?logo=windows&logoColor=00d4ff)

```
SCOM-CCS-Monitoring/
├── CentralCertificateStore.MP.xml      # The Management Pack
├── QUICKSTART.md                       # Quick start guide
├── README.md                           # This file
└── Scripts/
    ├── Discover-CentralCertificateStore.ps1
    ├── Discover-CentralCertificates.ps1
    └── Monitor-CertificateExpiration.ps1
```

---

## 📝 Changelog

### v1.0.0.0 (2026-01-11)
- 🚀 Initial release
- ✨ Central Certificate Store discovery
- ✨ Certificate discovery with issuer filtering
- ✨ Expiration monitoring with configurable 24-hour threshold
- ✨ Full override support for all key parameters

---

## 📄 License

[MIT](LICENSE) — do what you want, just give credit.

---

<p align="center">
  <a href="https://cheswick.dev">
    <img src="https://img.shields.io/badge/CHESWICK.DEV-00d4ff?logo=firefox&logoColor=0a0a0f&labelColor=a855f7" alt="cheswick.dev" />
  </a>
</p>

<p align="center">
  Made with 🖤 by <a href="https://cheswick.dev">cheswick.dev</a>
</p>
