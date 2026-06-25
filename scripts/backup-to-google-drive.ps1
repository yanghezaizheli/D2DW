param(
    [string]$ProjectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path,
    [string]$DestinationSubdir = 'D2DW-backups',
    [string]$DriveRoot = ''
)

$ErrorActionPreference = 'Stop'

function Get-DriveRoot {
    param([string]$RequestedDriveRoot)

    if ($RequestedDriveRoot) {
        if (-not (Test-Path -LiteralPath $RequestedDriveRoot -PathType Container)) {
            throw "Drive root does not exist: $RequestedDriveRoot"
        }
        return (Resolve-Path -LiteralPath $RequestedDriveRoot).Path
    }

    $profileDirs = Get-ChildItem -LiteralPath $env:USERPROFILE -Directory -Force
    $preferred = $profileDirs | Where-Object {
        $_.Name -like '*takamiya.cong@gmail.com*'
    } | Select-Object -First 1

    if ($preferred) {
        return $preferred.FullName
    }

    foreach ($candidateName in @('Google Drive', 'My Drive')) {
        $candidate = Join-Path $env:USERPROFILE $candidateName
        if (Test-Path -LiteralPath $candidate -PathType Container) {
            return (Resolve-Path -LiteralPath $candidate).Path
        }
    }

    throw 'Google Drive sync folder was not found under the user profile.'
}

$project = (Resolve-Path -LiteralPath $ProjectRoot).Path
$drive = Get-DriveRoot -RequestedDriveRoot $DriveRoot
$destination = Join-Path $drive $DestinationSubdir
New-Item -ItemType Directory -Path $destination -Force | Out-Null

$timestamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$archivePath = Join-Path $destination "D2DW-backup-$timestamp.zip"
$encryptedArchivePath = "$archivePath.enc"
$tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) "D2DW-backup-$timestamp"
$stagingRoot = Join-Path $tempRoot 'D2DW'

$excludedNames = @(
    '.git',
    '.vercel',
    '.claude',
    'node_modules',
    '__pycache__',
    '.pytest_cache',
    '.mypy_cache'
)

try {
    New-Item -ItemType Directory -Path $stagingRoot -Force | Out-Null

    Get-ChildItem -LiteralPath $project -Force | Where-Object {
        $excludedNames -notcontains $_.Name
    } | ForEach-Object {
        Copy-Item -LiteralPath $_.FullName -Destination $stagingRoot -Recurse -Force
    }

    $manifestPath = Join-Path $stagingRoot 'BACKUP_MANIFEST.txt'
    $manifest = @(
        "Project: $project",
        "Created: $((Get-Date).ToString('yyyy-MM-dd HH:mm:ss zzz'))",
        "Destination: $encryptedArchivePath",
        "Encryption: Windows DPAPI LocalMachine",
        '',
        'Excluded:',
        ($excludedNames | ForEach-Object { "- $_" })
    )

    if (Get-Command git -ErrorAction SilentlyContinue) {
        $branch = git -C $project branch --show-current 2>$null
        $status = git -C $project status --short 2>$null
        $manifest += @(
            '',
            "Git branch: $branch",
            '',
            'Git status:',
            $(if ($status) { $status } else { 'Clean' })
        )
    }

    $manifest | Set-Content -LiteralPath $manifestPath -Encoding UTF8

    Compress-Archive -LiteralPath $stagingRoot -DestinationPath $archivePath -Force

    $archive = Get-Item -LiteralPath $archivePath
    if ($archive.Length -le 0) {
        throw "Backup archive was created but is empty: $archivePath"
    }

    Add-Type -AssemblyName System.Security
    $plainBytes = [System.IO.File]::ReadAllBytes($archivePath)
    $encryptedBytes = [System.Security.Cryptography.ProtectedData]::Protect(
        $plainBytes,
        $null,
        [System.Security.Cryptography.DataProtectionScope]::LocalMachine
    )
    [System.IO.File]::WriteAllBytes($encryptedArchivePath, $encryptedBytes)
    Remove-Item -LiteralPath $archivePath -Force

    $encryptedArchive = Get-Item -LiteralPath $encryptedArchivePath
    if ($encryptedArchive.Length -le 0) {
        throw "Encrypted backup archive was created but is empty: $encryptedArchivePath"
    }

    Write-Output "Encrypted backup created: $encryptedArchivePath"
    Write-Output "Size bytes: $($encryptedArchive.Length)"
}
finally {
    if (Test-Path -LiteralPath $archivePath) {
        Remove-Item -LiteralPath $archivePath -Force
    }

    if (Test-Path -LiteralPath $tempRoot) {
        Remove-Item -LiteralPath $tempRoot -Recurse -Force
    }
}
