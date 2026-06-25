param(
    [Parameter(Mandatory = $true)]
    [string]$EncryptedBackupPath,
    [string]$OutputPath = ''
)

$ErrorActionPreference = 'Stop'

$encryptedPath = (Resolve-Path -LiteralPath $EncryptedBackupPath).Path

if (-not $OutputPath) {
    if ($encryptedPath.EndsWith('.enc')) {
        $OutputPath = $encryptedPath.Substring(0, $encryptedPath.Length - 4)
    }
    else {
        $OutputPath = "$encryptedPath.zip"
    }
}

Add-Type -AssemblyName System.Security
$encryptedBytes = [System.IO.File]::ReadAllBytes($encryptedPath)
$plainBytes = [System.Security.Cryptography.ProtectedData]::Unprotect(
    $encryptedBytes,
    $null,
    [System.Security.Cryptography.DataProtectionScope]::LocalMachine
)

[System.IO.File]::WriteAllBytes($OutputPath, $plainBytes)
$restored = Get-Item -LiteralPath $OutputPath

Write-Output "Restored ZIP: $($restored.FullName)"
Write-Output "Size bytes: $($restored.Length)"
