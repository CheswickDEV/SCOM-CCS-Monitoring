# Monitor-CertificateExpiration.ps1
# Monitors certificate expiration and alerts when within threshold
# Default threshold: 24 hours before expiration

param(
    [string]$thumbprint,
    [int]$warningThresholdHours = 24
)

# Create property bag for returning monitor state
$api = New-Object -ComObject 'MOM.ScriptAPI'
$propertyBag = $api.CreatePropertyBag()

try {
    # Get the Central Certificate Store path from registry
    $regPath = "HKLM:\SOFTWARE\Microsoft\IIS\CentralCertProvider"

    if (-not (Test-Path $regPath)) {
        $propertyBag.AddValue("State", "Error")
        $propertyBag.AddValue("Message", "Central Certificate Store registry path not found")
        $api.LogScriptEvent("Monitor-CertificateExpiration.ps1", 3001, 1, "Central Certificate Store registry path not found")
        $propertyBag
        return
    }

    $physicalPath = (Get-ItemProperty -Path $regPath -Name 'CertStoreLocation' -ErrorAction Stop).CertStoreLocation

    if (-not $physicalPath -or -not (Test-Path $physicalPath)) {
        $propertyBag.AddValue("State", "Error")
        $propertyBag.AddValue("Message", "Central Certificate Store physical path not found or inaccessible")
        $api.LogScriptEvent("Monitor-CertificateExpiration.ps1", 3002, 1, "Central Certificate Store physical path not found: $physicalPath")
        $propertyBag
        return
    }

    # Get the private key password (if configured)
    $privateKeyPassword = (Get-ItemProperty -Path $regPath -Name 'PrivateKeyPassword' -ErrorAction SilentlyContinue).PrivateKeyPassword

    # Find certificate by thumbprint
    $pfxFiles = Get-ChildItem -Path $physicalPath -Filter "*.pfx" -File -ErrorAction Stop
    $certificateFound = $false

    foreach ($pfxFile in $pfxFiles) {
        try {
            # Load certificate
            $cert = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2

            # Try to load with password if available
            if ($privateKeyPassword) {
                $securePassword = ConvertTo-SecureString -String $privateKeyPassword -AsPlainText -Force
                $cert.Import($pfxFile.FullName, $securePassword, [System.Security.Cryptography.X509Certificates.X509KeyStorageFlags]::DefaultKeySet)
            }
            else {
                try {
                    $cert.Import($pfxFile.FullName, "", [System.Security.Cryptography.X509Certificates.X509KeyStorageFlags]::DefaultKeySet)
                }
                catch {
                    # Skip password-protected certificates
                    continue
                }
            }

            # Check if this is the certificate we're looking for
            if ($cert.Thumbprint -eq $thumbprint) {
                $certificateFound = $true

                # Calculate time until expiration
                $now = Get-Date
                $expirationDate = $cert.NotAfter
                $timeUntilExpiration = $expirationDate - $now

                $hoursUntilExpiration = [math]::Round($timeUntilExpiration.TotalHours, 2)
                $daysUntilExpiration = [math]::Round($timeUntilExpiration.TotalDays, 2)

                # Check if certificate is expired
                if ($timeUntilExpiration.TotalSeconds -lt 0) {
                    $propertyBag.AddValue("State", "Critical")
                    $propertyBag.AddValue("Message", "Certificate has expired")
                    $propertyBag.AddValue("HoursUntilExpiration", $hoursUntilExpiration)
                    $propertyBag.AddValue("DaysUntilExpiration", $daysUntilExpiration)
                    $propertyBag.AddValue("ExpirationDate", $expirationDate.ToString("yyyy-MM-dd HH:mm:ss"))

                    $api.LogScriptEvent("Monitor-CertificateExpiration.ps1", 3003, 1,
                        "Certificate '$($cert.Subject)' has EXPIRED on $($expirationDate.ToString('yyyy-MM-dd HH:mm:ss'))")
                }
                # Check if certificate is within warning threshold
                elseif ($timeUntilExpiration.TotalHours -le $warningThresholdHours) {
                    $propertyBag.AddValue("State", "Warning")
                    $propertyBag.AddValue("Message", "Certificate expiring soon")
                    $propertyBag.AddValue("HoursUntilExpiration", $hoursUntilExpiration)
                    $propertyBag.AddValue("DaysUntilExpiration", $daysUntilExpiration)
                    $propertyBag.AddValue("ExpirationDate", $expirationDate.ToString("yyyy-MM-dd HH:mm:ss"))

                    $api.LogScriptEvent("Monitor-CertificateExpiration.ps1", 3004, 2,
                        "Certificate '$($cert.Subject)' will expire in $hoursUntilExpiration hours ($daysUntilExpiration days) on $($expirationDate.ToString('yyyy-MM-dd HH:mm:ss'))")
                }
                # Certificate is healthy
                else {
                    $propertyBag.AddValue("State", "Healthy")
                    $propertyBag.AddValue("Message", "Certificate is valid")
                    $propertyBag.AddValue("HoursUntilExpiration", $hoursUntilExpiration)
                    $propertyBag.AddValue("DaysUntilExpiration", $daysUntilExpiration)
                    $propertyBag.AddValue("ExpirationDate", $expirationDate.ToString("yyyy-MM-dd HH:mm:ss"))

                    $api.LogScriptEvent("Monitor-CertificateExpiration.ps1", 3000, 4,
                        "Certificate '$($cert.Subject)' is healthy. Expires in $hoursUntilExpiration hours ($daysUntilExpiration days) on $($expirationDate.ToString('yyyy-MM-dd HH:mm:ss'))")
                }

                $cert.Dispose()
                break
            }

            $cert.Dispose()
        }
        catch {
            # Continue to next certificate
            continue
        }
    }

    if (-not $certificateFound) {
        $propertyBag.AddValue("State", "Error")
        $propertyBag.AddValue("Message", "Certificate with thumbprint $thumbprint not found")
        $api.LogScriptEvent("Monitor-CertificateExpiration.ps1", 3005, 2, "Certificate with thumbprint $thumbprint not found in Central Certificate Store")
    }
}
catch {
    $propertyBag.AddValue("State", "Error")
    $propertyBag.AddValue("Message", "Error monitoring certificate: $($_.Exception.Message)")
    $api.LogScriptEvent("Monitor-CertificateExpiration.ps1", 3006, 1, "Error monitoring certificate expiration: $($_.Exception.Message)")
}

# Return property bag
$propertyBag
