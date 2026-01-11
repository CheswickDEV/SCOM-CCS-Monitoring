# Quick Start Guide

## Installation in 5 Minutes

### Step 1: Import Management Pack

```powershell
# Import the Management Pack
Import-SCOMManagementPack -FullName "C:\Path\To\CentralCertificateStore.MP.xml"
```

### Step 2: Verify Central Certificate Store Configuration

On your Windows Server with IIS:

```powershell
# Check CCS is configured
Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\IIS\CentralCertProvider"

# Expected output:
# Enabled           : 1
# CertStoreLocation : C:\CentralCertStore
# PrivateKeyPassword: [your password]
```

### Step 3: Wait for Discovery

- **Central Certificate Store discovery**: Runs every 4 hours (or wait up to 4 hours)
- **Certificate discovery**: Runs every 1 hour after CCS is discovered

To speed up testing, manually run discovery:

```powershell
# In SCOM PowerShell console
$discovery = Get-SCOMDiscovery -Name "*Certificate*"
Start-SCOMDiscovery -Discovery $discovery
```

### Step 4: Configure Issuer Filtering (Optional)

If you want to exclude certificates from specific issuers:

1. Open SCOM Console
2. Go to **Authoring** > **Management Pack Objects** > **Object Discoveries**
3. Find **Certificate Discovery**
4. Right-click > **Overrides** > **Override the Discovery** > **For all objects of class: Central Certificate Store**
5. Set **ExcludedIssuers** parameter:
   ```
   CN=Test CA;CN=Development CA
   ```
6. Save to your custom Management Pack

### Step 5: Test Monitoring

View discovered certificates:

```powershell
# Get all discovered certificates
Get-SCOMClassInstance -DisplayName "*Certificate*" |
    Select-Object DisplayName, HealthState |
    Format-Table -AutoSize
```

Check for alerts:

```powershell
# View certificate expiration alerts
Get-SCOMAlert -Name "*Certificate Expiring Soon*" |
    Select-Object Name, Severity, TimeRaised, ResolutionState |
    Format-Table -AutoSize
```

## Common Configuration Tasks

### Change Warning Threshold from 24h to 48h

1. **Authoring** > **Monitors**
2. Find **Certificate Expiration Monitor**
3. Right-click > **Overrides** > **Override the Monitor** > **For all objects of class: Certificate**
4. Change **WarningThresholdHours** from `24` to `48`
5. Save override

### Increase Monitoring Frequency

To check certificates every 30 minutes instead of every hour:

1. **Authoring** > **Monitors**
2. Find **Certificate Expiration Monitor**
3. Right-click > **Overrides** > **Override the Monitor** > **For all objects of class: Certificate**
4. Change **IntervalSeconds** from `3600` to `1800`
5. Save override

### View Monitoring Details

```powershell
# Check certificate properties
Get-SCOMClassInstance -DisplayName "*Certificate*" |
    ForEach-Object {
        $_.GetMonitoringProperties()
    } |
    Select-Object Name, Value |
    Format-Table -AutoSize

# View monitoring state
Get-SCOMMonitor -DisplayName "*Certificate Expiration*" |
    Get-SCOMMonitoringObject |
    Select-Object DisplayName, HealthState, LastModified |
    Format-Table -AutoSize
```

## Troubleshooting in 3 Steps

### 1. Check Discovery

```powershell
# View discovery last run
Get-SCOMDiscovery -DisplayName "*Certificate*" |
    Get-SCOMDiscoveryResult |
    Select-Object DiscoveryName, LastModified |
    Format-Table -AutoSize
```

### 2. Check Event Logs

On monitored server:

```powershell
# View recent discovery events
Get-EventLog -LogName "Operations Manager" -Newest 50 |
    Where-Object { $_.Source -eq "Health Service Script" -and
                   $_.Message -like "*Certificate*" } |
    Select-Object TimeGenerated, EntryType, Message |
    Format-Table -Wrap
```

### 3. Manual Test

Test scripts manually on target server:

```powershell
# Test certificate discovery
$regPath = "HKLM:\SOFTWARE\Microsoft\IIS\CentralCertProvider"
$storePath = (Get-ItemProperty -Path $regPath).CertStoreLocation

# List certificates
Get-ChildItem -Path $storePath -Filter "*.pfx" |
    ForEach-Object {
        $cert = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2
        $cert.Import($_.FullName, "", [System.Security.Cryptography.X509Certificates.X509KeyStorageFlags]::DefaultKeySet)

        [PSCustomObject]@{
            FileName = $_.Name
            Subject = $cert.Subject
            Issuer = $cert.Issuer
            NotAfter = $cert.NotAfter
            DaysUntilExpiration = ($cert.NotAfter - (Get-Date)).TotalDays
        }

        $cert.Dispose()
    } | Format-Table -AutoSize
```

## Need More Help?

Refer to the full [README.md](README.md) for detailed documentation.
