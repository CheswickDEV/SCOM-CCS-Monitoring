# Discover-CentralCertificates.ps1
# Discovers individual certificates in the Central Certificate Store
# Supports filtering by issuer to exclude certificates from specific CAs

param(
    [string]$sourceId,
    [string]$managedEntityId,
    [string]$computerName,
    [string]$excludedIssuers
)

# Create discovery data object
$api = New-Object -ComObject 'MOM.ScriptAPI'
$discoveryData = $api.CreateDiscoveryData(0, $sourceId, $managedEntityId)

try {
    # Get the Central Certificate Store path from registry
    $regPath = "HKLM:\SOFTWARE\Microsoft\IIS\CentralCertProvider"

    if (-not (Test-Path $regPath)) {
        $api.LogScriptEvent("Discover-CentralCertificates.ps1", 2001, 2, "Central Certificate Store registry path not found")
        $discoveryData
        return
    }

    $physicalPath = (Get-ItemProperty -Path $regPath -Name 'CertStoreLocation' -ErrorAction Stop).CertStoreLocation

    if (-not $physicalPath -or -not (Test-Path $physicalPath)) {
        $api.LogScriptEvent("Discover-CentralCertificates.ps1", 2002, 2, "Central Certificate Store physical path not found or inaccessible: $physicalPath")
        $discoveryData
        return
    }

    # Parse excluded issuers list (semicolon-separated)
    $excludedIssuerList = @()
    if ($excludedIssuers) {
        $excludedIssuerList = $excludedIssuers -split ';' | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne '' }
    }

    # Get the private key password (if configured)
    $privateKeyPassword = (Get-ItemProperty -Path $regPath -Name 'PrivateKeyPassword' -ErrorAction SilentlyContinue).PrivateKeyPassword

    # Get all PFX files from the Central Certificate Store
    $pfxFiles = Get-ChildItem -Path $physicalPath -Filter "*.pfx" -File -ErrorAction Stop

    $discoveredCount = 0
    $filteredCount = 0

    foreach ($pfxFile in $pfxFiles) {
        try {
            # Load certificate (without private key for discovery)
            $cert = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2

            # Try to load with password if available, otherwise without
            if ($privateKeyPassword) {
                $securePassword = ConvertTo-SecureString -String $privateKeyPassword -AsPlainText -Force
                $cert.Import($pfxFile.FullName, $securePassword, [System.Security.Cryptography.X509Certificates.X509KeyStorageFlags]::DefaultKeySet)
            }
            else {
                # Try without password (might fail for password-protected PFX)
                try {
                    $cert.Import($pfxFile.FullName, "", [System.Security.Cryptography.X509Certificates.X509KeyStorageFlags]::DefaultKeySet)
                }
                catch {
                    # Skip password-protected certificates if no password is configured
                    $api.LogScriptEvent("Discover-CentralCertificates.ps1", 2003, 2, "Could not load certificate $($pfxFile.Name): Password required")
                    continue
                }
            }

            # Check if issuer should be filtered out
            $shouldExclude = $false
            if ($excludedIssuerList.Count -gt 0) {
                foreach ($excludedIssuer in $excludedIssuerList) {
                    if ($cert.Issuer -like "*$excludedIssuer*") {
                        $shouldExclude = $true
                        $filteredCount++
                        break
                    }
                }
            }

            if ($shouldExclude) {
                $api.LogScriptEvent("Discover-CentralCertificates.ps1", 2004, 4, "Filtered out certificate '$($cert.Subject)' from issuer '$($cert.Issuer)'")
                continue
            }

            # Create certificate instance
            $certInstance = $discoveryData.CreateClassInstance("$MPElement[Name='CentralCertificateStore.MP.Certificate']$")

            # Set key property
            $certInstance.AddProperty("$MPElement[Name='CentralCertificateStore.MP.Certificate']/Thumbprint$", $cert.Thumbprint)

            # Set other properties
            $certInstance.AddProperty("$MPElement[Name='CentralCertificateStore.MP.Certificate']/Subject$", $cert.Subject)
            $certInstance.AddProperty("$MPElement[Name='CentralCertificateStore.MP.Certificate']/Issuer$", $cert.Issuer)
            $certInstance.AddProperty("$MPElement[Name='CentralCertificateStore.MP.Certificate']/NotBefore$", $cert.NotBefore.ToString("yyyy-MM-dd HH:mm:ss"))
            $certInstance.AddProperty("$MPElement[Name='CentralCertificateStore.MP.Certificate']/NotAfter$", $cert.NotAfter.ToString("yyyy-MM-dd HH:mm:ss"))
            $certInstance.AddProperty("$MPElement[Name='CentralCertificateStore.MP.Certificate']/FriendlyName$", $cert.FriendlyName)
            $certInstance.AddProperty("$MPElement[Name='System!System.Entity']/DisplayName$", "$($cert.Subject) (Expires: $($cert.NotAfter.ToString('yyyy-MM-dd')))")

            # Add instance to discovery data
            $discoveryData.AddInstance($certInstance)

            # Create hosting relationship
            $relationship = $discoveryData.CreateRelationshipInstance("$MPElement[Name='CentralCertificateStore.MP.CentralCertificateStoreHostsCertificate']$")
            $relationship.Source = $managedEntityId
            $relationship.Target = $certInstance
            $discoveryData.AddInstance($relationship)

            $discoveredCount++

            # Dispose certificate object
            $cert.Dispose()
        }
        catch {
            $api.LogScriptEvent("Discover-CentralCertificates.ps1", 2005, 2, "Error processing certificate file $($pfxFile.Name): $($_.Exception.Message)")
        }
    }

    $api.LogScriptEvent("Discover-CentralCertificates.ps1", 2000, 4, "Successfully discovered $discoveredCount certificates (filtered $filteredCount) from Central Certificate Store at: $physicalPath")
}
catch {
    $api.LogScriptEvent("Discover-CentralCertificates.ps1", 2006, 1, "Error discovering certificates: $($_.Exception.Message)")
}

# Return discovery data
$discoveryData
