# Create a self-signed certificate for MSIX signing
# Run this script from PowerShell as Administrator

param(
    [string]$SubjectName = "CN=pcHealth",
    [string]$FriendlyName = "pcHealth MSIX Signing",
    [string]$PfxPath = ".\pcHealth_Signing.pfx",
    [string]$CerPath = ".\pcHealth_Signing.cer",
    [string]$Password = "pcHealth"
)

# Check if running as administrator
if (-NOT ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Warning "This script requires Administrator privileges to create certificates in the LocalMachine store."
    exit 1
}

try {
    # Create the certificate with ECDSA P-384 for better performance
    $cert = New-SelfSignedCertificate \
        -Subject $SubjectName \
        -FriendlyName $FriendlyName \
        -KeyUsage DigitalSignature \
        -KeyAlgorithm ECDSA_P384 \
        -CertStoreLocation "Cert:\LocalMachine\My" \
        -NotAfter (Get-Date).AddYears(5)
    
    if (-not $cert) {
        throw "Failed to create certificate"
    }
    
    Write-Host "Certificate created in LocalMachine store with thumbprint: $($cert.Thumbprint)"
    
    # Export as PFX
    $securePassword = ConvertTo-SecureString -String $Password -Force -AsPlainText
    Export-PfxCertificate \
        -Cert $cert \
        -FilePath $PfxPath \
        -Password $securePassword \
        -Force
    
    Write-Host "PFX file exported to: $PfxPath"
    
    # Export as CER
    Export-Certificate \
        -Cert $cert \
        -FilePath $CerPath \
        -Type CERT \
        -Force
    
    Write-Host "CER file exported to: $CerPath"
    Write-Host "SUCCESS: Certificate files created successfully!"
    
} catch {
    Write-Error "Failed to create certificate: $_"
    exit 1
}
