# Central Certificate Store Monitoring Management Pack for SCOM

## Overview

This Management Pack provides comprehensive monitoring of SSL/TLS certificates stored in the Windows Central Certificate Store (CCS) for System Center Operations Manager (SCOM).

## Features

- **Automatic Discovery**: Discovers the Central Certificate Store and all certificates within it
- **Expiration Monitoring**: Monitors certificate expiration and alerts when certificates are within 24 hours of expiring
- **Issuer Filtering**: Allows filtering to exclude certificates from specific certificate authorities (issuers)
- **Detailed Alerting**: Provides comprehensive alert information including subject, expiration date, and issuer details
- **Configurable Thresholds**: Override warning thresholds and monitoring intervals as needed

## Requirements

- System Center Operations Manager 2012 R2 or later
- Windows Server 2012 or later with IIS Central Certificate Store configured
- PowerShell 4.0 or later
- Appropriate permissions to access the Central Certificate Store path

## Installation

1. Import the Management Pack into SCOM:
   ```powershell
   Import-SCOMManagementPack -FullName "CentralCertificateStore.MP.xml"
   ```

2. Wait for discovery to complete (initial discovery runs every 4 hours for CCS, every hour for certificates)

3. Configure issuer filtering if needed (see Configuration section below)

## Configuration

### Excluding Certificates by Issuer

To exclude certificates from specific issuers (e.g., internal test CAs), you need to override the `ExcludedIssuers` property:

1. In SCOM Console, go to **Authoring** > **Management Pack Objects** > **Object Discoveries**
2. Find **Certificate Discovery** (CentralCertificateStore.MP.Certificate.Discovery)
3. Right-click and select **Overrides** > **Override the Discovery** > **For all objects of class: Central Certificate Store**
4. Set the **ExcludedIssuers** parameter with a semicolon-separated list of issuer names or patterns:
   ```
   CN=Internal Test CA;CN=Dev Certificate Authority;O=Test Organization
   ```
5. Save the override to an appropriate Management Pack

### Adjusting Warning Threshold

The default warning threshold is 24 hours before expiration. To change this:

1. Go to **Authoring** > **Management Pack Objects** > **Monitors**
2. Find **Certificate Expiration Monitor** (CentralCertificateStore.MP.Certificate.ExpirationMonitor)
3. Right-click and select **Overrides** > **Override the Monitor** > **For all objects of class: Certificate**
4. Adjust the **WarningThresholdHours** parameter (e.g., set to 48 for 2 days warning)
5. Save the override to an appropriate Management Pack

### Adjusting Discovery and Monitoring Intervals

To change how frequently discoveries and monitoring run:

1. **Central Certificate Store Discovery** (default: 4 hours):
   - Override the **IntervalSeconds** parameter
   - Example: 7200 for 2 hours

2. **Certificate Discovery** (default: 1 hour):
   - Override the **IntervalSeconds** parameter in Certificate Discovery

3. **Certificate Expiration Monitor** (default: 1 hour):
   - Override the **IntervalSeconds** parameter in Certificate Expiration Monitor

## Certificate Store Configuration

The Management Pack reads the Central Certificate Store configuration from the registry:

- **Registry Path**: `HKLM:\SOFTWARE\Microsoft\IIS\CentralCertProvider`
- **Required Keys**:
  - `Enabled` (DWORD): Must be set to 1
  - `CertStoreLocation` (String): Physical path to the certificate store (e.g., `C:\CentralCertStore`)
  - `PrivateKeyPassword` (String, Optional): Password for PFX files

## Monitoring Details

### Discovery Process

1. **Central Certificate Store Discovery**:
   - Runs every 4 hours on Windows Server Operating Systems
   - Checks registry for CCS configuration
   - Creates a single CCS instance per server if configured

2. **Certificate Discovery**:
   - Runs every hour on discovered CCS instances
   - Reads all PFX files from the configured path
   - Filters out certificates from excluded issuers
   - Creates certificate instances with properties:
     - Thumbprint (unique identifier)
     - Subject
     - Issuer
     - Valid From (NotBefore)
     - Valid Until (NotAfter)
     - Friendly Name

### Monitoring Process

**Certificate Expiration Monitor**:
- Runs every hour for each discovered certificate
- Calculates time until expiration
- Raises **Warning** alert when expiration is within threshold (default: 24 hours)
- Automatically resolves when certificate is renewed or time extends beyond threshold
- Alert includes:
  - Certificate subject
  - Expiration date and time
  - Issuer information
  - Hours until expiration

### Health States

- **Healthy**: Certificate is valid and not within warning threshold
- **Warning**: Certificate will expire within the configured threshold
- **Critical**: Certificate has already expired (Note: Current version uses Warning for imminent expiration)

## Troubleshooting

### Certificates Not Discovered

1. Verify Central Certificate Store is properly configured:
   ```powershell
   Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\IIS\CentralCertProvider"
   ```

2. Check that the certificate store path exists and is accessible
3. Verify PFX files exist in the configured path
4. Check SCOM event logs for discovery script errors (Event IDs 2000-2006)

### Certificates Discovered But Not Monitored

1. Check SCOM event logs for monitoring script errors (Event IDs 3000-3006)
2. Verify certificate files are not corrupted
3. Confirm password-protected PFX files have correct password configured in registry

### Filtering Not Working

1. Verify the override is properly saved and applied
2. Check issuer names match exactly (partial matching with wildcards is supported)
3. Use semicolon (;) as separator for multiple issuers
4. Wait for next discovery cycle (1 hour) or manually run discovery

### View Event Log Messages

```powershell
# View discovery events
Get-EventLog -LogName "Operations Manager" -Source "Health Service Script" |
    Where-Object { $_.Message -like "*Discover-Central*" } |
    Select-Object TimeGenerated, EntryType, Message

# View monitoring events
Get-EventLog -LogName "Operations Manager" -Source "Health Service Script" |
    Where-Object { $_.Message -like "*Monitor-Certificate*" } |
    Select-Object TimeGenerated, EntryType, Message
```

## Event IDs

### Discovery Events

- **1000**: Central Certificate Store discovered successfully
- **1001**: Central Certificate Store not enabled
- **1002**: Central Certificate Store registry key not found
- **1003**: Error during CCS discovery
- **2000**: Certificates discovered successfully
- **2001-2006**: Various certificate discovery errors and warnings

### Monitoring Events

- **3000**: Certificate is healthy
- **3003**: Certificate has expired (Critical)
- **3004**: Certificate expiring soon (Warning)
- **3005**: Certificate not found
- **3006**: Monitoring error

## Best Practices

1. **Set appropriate thresholds**: Consider certificate renewal processes and timelines
2. **Configure issuer filtering**: Exclude internal test CAs to reduce noise
3. **Regular testing**: Periodically test with certificates close to expiration
4. **Alert routing**: Configure notification subscriptions for certificate alerts
5. **Documentation**: Maintain documentation of which applications use which certificates
6. **Automated renewal**: Integrate with certificate renewal processes to auto-resolve alerts

## Security Considerations

- The Management Pack reads certificates with read-only access
- Private key passwords are stored in registry (consider using encrypted storage)
- SCOM agent service account requires read access to CCS path
- Consider restricting access to override MPs that contain issuer filters

## Version History

- **1.0.0.0** (2026-01-11): Initial release
  - Central Certificate Store discovery
  - Certificate discovery with issuer filtering
  - Certificate expiration monitoring with 24-hour threshold
  - Configurable overrides for all key parameters

## Support

For issues, questions, or feature requests, please refer to your organization's SCOM support channels.

---

# Management Pack für die Überwachung des zentralen Zertifikatspeichers für SCOM

## Übersicht

Dieses Management Pack bietet eine umfassende Überwachung von SSL/TLS-Zertifikaten, die im zentralen Zertifikatspeicher (Central Certificate Store, CCS) von Windows für System Center Operations Manager (SCOM) gespeichert sind.

## Funktionen

- **Automatische Erkennung**: Erkennt den zentralen Zertifikatspeicher und alle darin enthaltenen Zertifikate
- **Ablaufüberwachung**: Überwacht den Ablauf von Zertifikaten und warnt, wenn Zertifikate innerhalb von 24 Stunden ablaufen
- **Aussteller-Filterung**: Ermöglicht das Filtern, um Zertifikate von bestimmten Zertifizierungsstellen (Ausstellern) auszuschließen
- **Detaillierte Warnmeldungen**: Bietet umfassende Warninformationen einschließlich Betreff, Ablaufdatum und Ausstellerdetails
- **Konfigurierbare Schwellenwerte**: Überschreiben Sie Warnschwellenwerte und Überwachungsintervalle nach Bedarf

## Anforderungen

- System Center Operations Manager 2012 R2 oder höher
- Windows Server 2012 oder höher mit konfiguriertem IIS Central Certificate Store
- PowerShell 4.0 oder höher
- Entsprechende Berechtigungen für den Zugriff auf den Central Certificate Store-Pfad

## Installation

1. Importieren Sie das Management Pack in SCOM:
   ```powershell
   Import-SCOMManagementPack -FullName "CentralCertificateStore.MP.xml"
   ```

2. Warten Sie, bis die Erkennung abgeschlossen ist (erste Erkennung läuft alle 4 Stunden für CCS, jede Stunde für Zertifikate)

3. Konfigurieren Sie bei Bedarf die Aussteller-Filterung (siehe Abschnitt Konfiguration unten)

## Konfiguration

### Ausschließen von Zertifikaten nach Aussteller

Um Zertifikate von bestimmten Ausstellern auszuschließen (z.B. interne Test-CAs), müssen Sie die Eigenschaft `ExcludedIssuers` überschreiben:

1. Gehen Sie in der SCOM-Konsole zu **Erstellung** > **Management Pack-Objekte** > **Objekterkennungen**
2. Suchen Sie **Certificate Discovery** (CentralCertificateStore.MP.Certificate.Discovery)
3. Klicken Sie mit der rechten Maustaste und wählen Sie **Überschreibungen** > **Erkennung überschreiben** > **Für alle Objekte der Klasse: Central Certificate Store**
4. Setzen Sie den Parameter **ExcludedIssuers** mit einer durch Semikolon getrennten Liste von Ausstellernamen oder -mustern:
   ```
   CN=Interne Test CA;CN=Dev Zertifizierungsstelle;O=Test Organisation
   ```
5. Speichern Sie die Überschreibung in einem geeigneten Management Pack

### Anpassen des Warnschwellenwerts

Der Standard-Warnschwellenwert liegt 24 Stunden vor Ablauf. Um dies zu ändern:

1. Gehen Sie zu **Erstellung** > **Management Pack-Objekte** > **Monitore**
2. Suchen Sie **Certificate Expiration Monitor** (CentralCertificateStore.MP.Certificate.ExpirationMonitor)
3. Klicken Sie mit der rechten Maustaste und wählen Sie **Überschreibungen** > **Monitor überschreiben** > **Für alle Objekte der Klasse: Certificate**
4. Passen Sie den Parameter **WarningThresholdHours** an (z.B. auf 48 für 2 Tage Warnung setzen)
5. Speichern Sie die Überschreibung in einem geeigneten Management Pack

## Fehlerbehebung

### Zertifikate werden nicht erkannt

1. Überprüfen Sie, ob der zentrale Zertifikatspeicher ordnungsgemäß konfiguriert ist:
   ```powershell
   Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\IIS\CentralCertProvider"
   ```

2. Überprüfen Sie, ob der Zertifikatspeicherpfad existiert und zugänglich ist
3. Überprüfen Sie, ob PFX-Dateien im konfigurierten Pfad vorhanden sind
4. Überprüfen Sie die SCOM-Ereignisprotokolle auf Erkennungsskriptfehler (Ereignis-IDs 2000-2006)

### Zertifikate erkannt, aber nicht überwacht

1. Überprüfen Sie die SCOM-Ereignisprotokolle auf Überwachungsskriptfehler (Ereignis-IDs 3000-3006)
2. Überprüfen Sie, ob die Zertifikatsdateien nicht beschädigt sind
3. Bestätigen Sie, dass passwortgeschützte PFX-Dateien das richtige Passwort in der Registrierung konfiguriert haben

### Filterung funktioniert nicht

1. Überprüfen Sie, ob die Überschreibung ordnungsgemäß gespeichert und angewendet wurde
2. Überprüfen Sie, ob die Ausstellernamen genau übereinstimmen (teilweise Übereinstimmung mit Wildcards wird unterstützt)
3. Verwenden Sie Semikolon (;) als Trennzeichen für mehrere Aussteller
4. Warten Sie auf den nächsten Erkennungszyklus (1 Stunde) oder führen Sie die Erkennung manuell aus

## Best Practices

1. **Setzen Sie geeignete Schwellenwerte**: Berücksichtigen Sie Zertifikatserneuerungsprozesse und Zeitpläne
2. **Konfigurieren Sie die Aussteller-Filterung**: Schließen Sie interne Test-CAs aus, um Rauschen zu reduzieren
3. **Regelmäßige Tests**: Testen Sie regelmäßig mit Zertifikaten, die kurz vor dem Ablauf stehen
4. **Alarm-Routing**: Konfigurieren Sie Benachrichtigungsabonnements für Zertifikatswarnungen
5. **Automatische Erneuerung**: Integrieren Sie mit Zertifikatserneuerungsprozessen, um Warnungen automatisch aufzulösen

## Versionsverlauf

- **1.0.0.0** (2026-01-11): Erste Version
  - Erkennung des zentralen Zertifikatspeichers
  - Zertifikatserkennung mit Aussteller-Filterung
  - Überwachung des Zertifikatsablaufs mit 24-Stunden-Schwellenwert
  - Konfigurierbare Überschreibungen für alle wichtigen Parameter
