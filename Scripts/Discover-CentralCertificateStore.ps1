# Discover-CentralCertificateStore.ps1
# Discovers the Windows Central Certificate Store for IIS
# This script checks if the CCS feature is installed and configured

param(
    [string]$sourceId,
    [string]$managedEntityId,
    [string]$computerName
)

# Create discovery data object
$api = New-Object -ComObject 'MOM.ScriptAPI'
$discoveryData = $api.CreateDiscoveryData(0, $sourceId, $managedEntityId)

try {
    # Check if IIS Central Certificate Store is configured
    $iisPath = "IIS:\SslBindings"

    # Try to import WebAdministration module
    if (-not (Get-Module -Name WebAdministration -ErrorAction SilentlyContinue)) {
        Import-Module WebAdministration -ErrorAction Stop
    }

    # Get the Central Certificate Store configuration
    $ccsConfig = Get-WebConfigurationProperty -PSPath 'MACHINE/WEBROOT/APPHOST' `
                                               -Filter 'system.webServer/security/authentication/iisClientCertificateMappingAuthentication' `
                                               -Name 'enabled' `
                                               -ErrorAction SilentlyContinue

    # Check registry for CCS configuration
    $regPath = "HKLM:\SOFTWARE\Microsoft\IIS\CentralCertProvider"
    $ccsEnabled = $false
    $physicalPath = ""

    if (Test-Path $regPath) {
        $ccsEnabled = (Get-ItemProperty -Path $regPath -Name 'Enabled' -ErrorAction SilentlyContinue).Enabled
        $physicalPath = (Get-ItemProperty -Path $regPath -Name 'CertStoreLocation' -ErrorAction SilentlyContinue).CertStoreLocation

        if ($ccsEnabled -eq 1 -and $physicalPath) {
            # Create instance of Central Certificate Store
            $instance = $discoveryData.CreateClassInstance("$MPElement[Name='CentralCertificateStore.MP.CentralCertificateStore']$")

            # Set properties
            $instance.AddProperty("$MPElement[Name='Windows!Microsoft.Windows.Computer']/PrincipalName$", $computerName)
            $instance.AddProperty("$MPElement[Name='CentralCertificateStore.MP.CentralCertificateStore']/StorePhysicalPath$", $physicalPath)
            $instance.AddProperty("$MPElement[Name='CentralCertificateStore.MP.CentralCertificateStore']/ExcludedIssuers$", "")
            $instance.AddProperty("$MPElement[Name='System!System.Entity']/DisplayName$", "Central Certificate Store on $computerName")

            # Add instance to discovery data
            $discoveryData.AddInstance($instance)

            $api.LogScriptEvent("Discover-CentralCertificateStore.ps1", 1000, 4, "Successfully discovered Central Certificate Store at: $physicalPath")
        }
        else {
            $api.LogScriptEvent("Discover-CentralCertificateStore.ps1", 1001, 4, "Central Certificate Store is not enabled or configured on $computerName")
        }
    }
    else {
        $api.LogScriptEvent("Discover-CentralCertificateStore.ps1", 1002, 4, "Central Certificate Store registry key not found on $computerName")
    }
}
catch {
    $api.LogScriptEvent("Discover-CentralCertificateStore.ps1", 1003, 1, "Error discovering Central Certificate Store: $($_.Exception.Message)")
}

# Return discovery data
$discoveryData
