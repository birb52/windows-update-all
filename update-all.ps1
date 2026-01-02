<#
update-all.ps1
Minimal Windows package updater for Winget, Chocolatey, and Scoop.

Author: Sathvik
License: MIT
#>

param(
    [switch]$Scoop,
    [switch]$Choco,
    [switch]$Winget,
    [switch]$All,
    [switch]$Check
)

function Test-Command {
    param ($cmd)
    return [bool](Get-Command $cmd -ErrorAction SilentlyContinue)
}

Write-Host "-- System Package Update --`n"

# If no flags are provided, default to --all
if (-not ($Scoop -or $Choco -or $Winget -or $All)) {
    $All = $true
}

if ($All) {
    $Scoop  = $true
    $Choco  = $true
    $Winget = $true
}

# --- Scoop ---
if ($Scoop) {
    if (Test-Command "scoop") {

        if ($Check) {
            Write-Host "[Scoop] Checking for updates..."
            scoop status
        } else {
            Write-Host "[Scoop] Finding upgradable packages..."

            $outdated = scoop status |
                Select-String '^\S+' |
                ForEach-Object { $_.ToString().Split()[0] }

            if (-not $outdated) {
                Write-Host "[Scoop] No updates available."
            } else {
                foreach ($app in $outdated) {
                    Write-Host "[Scoop] Updating $app"
                    scoop update $app | Out-Null
                }
            }
        }

    } else {
        Write-Host "[Scoop] Not installed, skipping."
    }

    Write-Host ""
}

# --- Chocolatey ---
if ($Choco) {
    if (Test-Command "choco") {

        if ($Check) {
            Write-Host "[Chocolatey] Checking for updates..."
            choco outdated
        } else {
            Write-Host "[Chocolatey] Finding upgradable packages..."

            $outdated = choco outdated --limit-output |
                ForEach-Object { ($_ -split '\|')[0] }

            if (-not $outdated) {
                Write-Host "[Chocolatey] No updates available."
            } else {
                foreach ($pkg in $outdated) {
                    Write-Host "[Chocolatey] Updating $pkg"
                    choco upgrade $pkg -y --no-progress | Out-Null
                }
            }
        }

    } else {
        Write-Host "[Chocolatey] Not installed, skipping."
    }

    Write-Host ""
}

# --- Winget ---
if ($Winget) {
    if (Test-Command "winget") {

        if ($Check) {
            Write-Host "[Winget] Checking for updates..."
            winget upgrade
        } else {
            Write-Host "[Winget] Finding upgradable packages..."

            # Capture *everything* winget emits
            $raw = winget upgrade --output json `
                --accept-source-agreements `
                --disable-interactivity 2>&1 | Out-String

            # Extract JSON object only (PS 5.1-safe)
            if ($raw -match '\{[\s\S]*\}$') {
                $json = $matches[0]
                $data = $json | ConvertFrom-Json
            } else {
                Write-Host "[Winget] No updates available."
                Write-Host ""
                return
            }

            $packages = $data.Sources |
                ForEach-Object { $_.Packages } |
                Where-Object { $_ }

            if (-not $packages) {
                Write-Host "[Winget] No updates available."
            } else {
                foreach ($pkg in $packages) {
                    $name = $pkg.PackageName
                    $id   = $pkg.PackageIdentifier

                    Write-Host "[Winget] Updating $name"

                    winget upgrade `
                        --id $id `
                        --silent `
                        --accept-package-agreements `
                        --accept-source-agreements `
                        --disable-interactivity | Out-Null
                }
            }
        }

    } else {
        Write-Host "[Winget] Not installed, skipping."
    }

    Write-Host ""
}

Write-Host "`n-- Done --"

