#Requires -Version 5.1
<#
.SYNOPSIS
    WSL2 NixOS Backup Orchestrator for hp-probook-wsl

.DESCRIPTION
    PowerShell script that orchestrates WSL backup operations:
    - Safely shuts down WSL distribution
    - Exports WSL distribution to tar archive (full backup)
    - Launches Bash backup script for incremental rsync backups
    - Restarts WSL distribution
    - Sends Windows notifications

.PARAMETER Mode
    Operation mode: Backup, Restore, or Verify
    Default: Backup

.PARAMETER BackupDir
    Backup destination directory (Windows path)
    Default: D:\Backups\WSL-NixOS

.PARAMETER DistroName
    WSL distribution name
    Default: NixOS

.PARAMETER SkipExport
    Skip full WSL distribution export (only run incremental backup)

.PARAMETER NoRestart
    Don't restart WSL after backup completes

.EXAMPLE
    .\WSL-Backup-Orchestrator.ps1
    Runs full backup with default settings

.EXAMPLE
    .\WSL-Backup-Orchestrator.ps1 -Mode Restore
    Runs restore mode

.EXAMPLE
    .\WSL-Backup-Orchestrator.ps1 -SkipExport
    Runs only incremental backup, skips full export

.NOTES
    Author: NixOS Configuration Management
    Version: 1.0.0
#>

[CmdletBinding()]
param(
    [Parameter(Position = 0)]
    [ValidateSet('Backup', 'Restore', 'Verify')]
    [string]$Mode = 'Backup',

    [Parameter()]
    [string]$BackupDir = 'D:\Backups\WSL-NixOS',

    [Parameter()]
    [string]$DistroName = 'NixOS',

    [Parameter()]
    [switch]$SkipExport,

    [Parameter()]
    [switch]$NoRestart
)

################################################################################
# CONFIGURATION
################################################################################

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'Continue'

# Backup script location inside WSL
$BashScriptPath = '/per/etc/nixos/scripts/wsl-backup-hpprobook.sh'

# Logging
$LogDir = Join-Path $env:TEMP 'WSL-Backup-Logs'
$LogFile = Join-Path $LogDir "backup_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"

# Notification settings
$NotificationTitle = 'WSL Backup'

################################################################################
# UTILITY FUNCTIONS
################################################################################

function Write-Log {
    param(
        [Parameter(Mandatory)]
        [string]$Message,

        [Parameter()]
        [ValidateSet('Info', 'Warning', 'Error', 'Success')]
        [string]$Level = 'Info'
    )

    $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    $logMessage = "[$timestamp] [$Level] $Message"

    # Create log directory if needed
    if (-not (Test-Path $LogDir)) {
        New-Item -ItemType Directory -Path $LogDir -Force | Out-Null
    }

    # Write to log file
    Add-Content -Path $LogFile -Value $logMessage

    # Write to console with color
    switch ($Level) {
        'Info'    { Write-Host $logMessage -ForegroundColor Cyan }
        'Warning' { Write-Host $logMessage -ForegroundColor Yellow }
        'Error'   { Write-Host $logMessage -ForegroundColor Red }
        'Success' { Write-Host $logMessage -ForegroundColor Green }
    }
}

function Send-Notification {
    param(
        [Parameter(Mandatory)]
        [string]$Title,

        [Parameter(Mandatory)]
        [string]$Message,

        [Parameter()]
        [ValidateSet('Info', 'Warning', 'Error')]
        [string]$Type = 'Info'
    )

    try {
        # Use Windows toast notification
        Add-Type -AssemblyName System.Windows.Forms

        $notification = New-Object System.Windows.Forms.NotifyIcon
        $notification.Icon = [System.Drawing.SystemIcons]::Information
        $notification.BalloonTipIcon = $Type
        $notification.BalloonTipText = $Message
        $notification.BalloonTipTitle = $Title
        $notification.Visible = $True

        $notification.ShowBalloonTip(5000)

        # Clean up
        Start-Sleep -Seconds 1
        $notification.Dispose()
    }
    catch {
        Write-Log "Failed to send notification: $_" -Level Warning
    }
}

function Test-WSLDistribution {
    param([string]$Name)

    $distros = wsl --list --quiet
    return $distros -contains $Name
}

function Get-WSLDistributionState {
    param([string]$Name)

    try {
        # Get running distributions and clean up output
        $output = wsl --list --running --quiet 2>&1

        if ($output) {
            # Convert to string array and clean each line
            $runningDistros = @($output | ForEach-Object {
                $_.ToString().Trim() -replace '\0', ''
            } | Where-Object { $_ -ne '' })

            # Check if our distro is in the list
            foreach ($distro in $runningDistros) {
                if ($distro -eq $Name) {
                    return $true
                }
            }
        }

        return $false
    }
    catch {
        Write-Log "Error checking WSL state: $_" -Level Warning
        return $false
    }
}

function Stop-WSLDistribution {
    param([string]$Name)

    Write-Log "Checking WSL distribution state: $Name" -Level Info

    if (Get-WSLDistributionState -Name $Name) {
        Write-Log "Shutting down WSL distribution: $Name" -Level Info

        # Try graceful shutdown first
        try {
            wsl -d $Name --exec sudo shutdown -h now 2>&1 | Out-Null
            Write-Log "Waiting for graceful shutdown..." -Level Info
            Start-Sleep -Seconds 8
        }
        catch {
            Write-Log "Graceful shutdown command failed, will use terminate" -Level Warning
        }

        # Check if still running and use wsl --terminate
        $retryCount = 0
        $maxRetries = 3

        while ((Get-WSLDistributionState -Name $Name) -and ($retryCount -lt $maxRetries)) {
            Write-Log "WSL still running, attempting terminate (attempt $($retryCount + 1)/$maxRetries)" -Level Warning
            wsl --terminate $Name 2>&1 | Out-Null
            Start-Sleep -Seconds 3
            $retryCount++
        }

        # Final check with extended wait
        Start-Sleep -Seconds 2

        if (Get-WSLDistributionState -Name $Name) {
            Write-Log "WSL distribution may still be running, but proceeding with backup" -Level Warning
            Write-Log "Note: Full WSL export will be skipped if WSL is running" -Level Warning
        }
        else {
            Write-Log "WSL distribution stopped successfully" -Level Success
        }
    }
    else {
        Write-Log "WSL distribution is not running" -Level Info
    }
}

function Start-WSLDistribution {
    param([string]$Name)

    Write-Log "Starting WSL distribution: $Name" -Level Info

    try {
        # Start WSL by running a simple command
        wsl -d $Name --exec echo "WSL started" | Out-Null
        Start-Sleep -Seconds 2

        if (Get-WSLDistributionState -Name $Name) {
            Write-Log "WSL distribution started successfully" -Level Success
        }
        else {
            Write-Log "WSL distribution failed to start" -Level Warning
        }
    }
    catch {
        Write-Log "Error starting WSL: $_" -Level Error
    }
}

function Export-WSLDistribution {
    param(
        [string]$Name,
        [string]$Destination
    )

    Write-Log "Starting full WSL distribution export" -Level Info
    Write-Log "Distro: $Name" -Level Info
    Write-Log "Destination: $Destination" -Level Info

    # Create destination directory
    $destDir = Split-Path $Destination -Parent
    if (-not (Test-Path $destDir)) {
        New-Item -ItemType Directory -Path $destDir -Force | Out-Null
        Write-Log "Created backup directory: $destDir" -Level Info
    }

    # Check available disk space
    $drive = (Split-Path $Destination -Qualifier)
    $driveInfo = Get-PSDrive ($drive -replace ':', '')
    $freeSpaceGB = [math]::Round($driveInfo.Free / 1GB, 2)

    Write-Log "Available disk space: ${freeSpaceGB}GB" -Level Info

    if ($freeSpaceGB -lt 10) {
        Write-Log "Low disk space warning: ${freeSpaceGB}GB available" -Level Warning
    }

    # Perform export
    try {
        Write-Log "Exporting WSL distribution (this may take several minutes)..." -Level Info
        $exportStartTime = Get-Date

        # Start export process with output capture
        $psi = New-Object System.Diagnostics.ProcessStartInfo
        $psi.FileName = "wsl.exe"
        $psi.Arguments = "--export $Name `"$Destination`""
        $psi.RedirectStandardOutput = $true
        $psi.RedirectStandardError = $true
        $psi.UseShellExecute = $false
        $psi.CreateNoWindow = $true

        $process = New-Object System.Diagnostics.Process
        $process.StartInfo = $psi

        # Event handlers for output streams
        $stdoutHandler = {
            if (-not [string]::IsNullOrWhiteSpace($EventArgs.Data)) {
                $line = $EventArgs.Data.Trim()
                # Parse and format progress messages
                if ($line -match '^Export in progress') {
                    Write-Log $line -Level Info
                }
                elseif ($line -match '\(\d+\s+MB\)') {
                    # Progress update with size
                    Write-Log $line -Level Info
                }
                else {
                    Write-Log $line -Level Info
                }
            }
        }

        $stderrHandler = {
            if (-not [string]::IsNullOrWhiteSpace($EventArgs.Data)) {
                $line = $EventArgs.Data.Trim()
                # Categorize error messages
                if ($line -match 'pax format cannot archive|cannot archive sockets') {
                    Write-Log $line -Level Warning
                }
                elseif ($line -match 'Error code:|not enough space|failed') {
                    Write-Log $line -Level Error
                }
                else {
                    Write-Log $line -Level Warning
                }
            }
        }

        $process.add_OutputDataReceived($stdoutHandler)
        $process.add_ErrorDataReceived($stderrHandler)

        # Start process and begin reading output
        $null = $process.Start()
        $process.BeginOutputReadLine()
        $process.BeginErrorReadLine()

        # Wait for completion
        $process.WaitForExit()

        $exitCode = $process.ExitCode

        if ($exitCode -ne 0) {
            throw "WSL export failed with exit code: $exitCode"
        }

        $exportDuration = (Get-Date) - $exportStartTime
        Write-Log "Export completed in $($exportDuration.TotalMinutes.ToString('0.00')) minutes" -Level Success

        # Get export file size
        if (Test-Path $Destination) {
            $fileSize = (Get-Item $Destination).Length
            $fileSizeGB = [math]::Round($fileSize / 1GB, 2)
            Write-Log "Export file size: ${fileSizeGB}GB" -Level Info
        }
    }
    catch {
        Write-Log "Export failed: $_" -Level Error
        throw
    }
}

function Invoke-WSLBackupScript {
    param(
        [string]$DistroName,
        [string]$ScriptPath,
        [string]$Mode
    )

    Write-Log "Invoking WSL backup script" -Level Info
    Write-Log "Script: $ScriptPath" -Level Info
    Write-Log "Mode: $Mode" -Level Info

    try {
        # Check if script exists
        $scriptCheck = wsl -d $DistroName --exec test -f $ScriptPath
        if ($LASTEXITCODE -ne 0) {
            throw "Backup script not found: $ScriptPath"
        }

        # Make script executable
        wsl -d $DistroName --exec chmod +x $ScriptPath

        # Run backup script
        Write-Log "Running backup script..." -Level Info
        wsl -d $DistroName --exec bash $ScriptPath $Mode.ToLower()

        if ($LASTEXITCODE -eq 0) {
            Write-Log "Backup script completed successfully" -Level Success
        }
        else {
            throw "Backup script exited with code: $LASTEXITCODE"
        }
    }
    catch {
        Write-Log "Backup script failed: $_" -Level Error
        throw
    }
}

function Remove-OldBackups {
    param(
        [string]$BackupPath,
        [int]$KeepCount = 3
    )

    Write-Log "Rotating old backups in: $BackupPath" -Level Info

    $fullBackupDir = Join-Path $BackupPath 'full'

    if (Test-Path $fullBackupDir) {
        $backups = Get-ChildItem -Path $fullBackupDir -Filter '*.tar' |
                   Sort-Object CreationTime -Descending

        if ($backups.Count -gt $KeepCount) {
            $toDelete = $backups | Select-Object -Skip $KeepCount

            foreach ($backup in $toDelete) {
                Write-Log "Deleting old backup: $($backup.Name)" -Level Info
                Remove-Item $backup.FullName -Force
            }

            Write-Log "Deleted $($toDelete.Count) old backup(s)" -Level Info
        }
        else {
            Write-Log "No old backups to delete (found $($backups.Count), keeping $KeepCount)" -Level Info
        }
    }
}

################################################################################
# MAIN EXECUTION
################################################################################

function Main {
    Write-Log '==========================================' -Level Info
    Write-Log 'WSL Backup Orchestrator Started' -Level Info
    Write-Log "Mode: $Mode" -Level Info
    Write-Log "Distribution: $DistroName" -Level Info
    Write-Log "Backup Directory: $BackupDir" -Level Info
    Write-Log '==========================================' -Level Info

    try {
        # Verify WSL distribution exists
        if (-not (Test-WSLDistribution -Name $DistroName)) {
            throw "WSL distribution not found: $DistroName"
        }

        # Create backup directory
        if (-not (Test-Path $BackupDir)) {
            New-Item -ItemType Directory -Path $BackupDir -Force | Out-Null
            Write-Log "Created backup directory: $BackupDir" -Level Info
        }

        # Stop WSL distribution
        Stop-WSLDistribution -Name $DistroName

        # Perform full export (unless skipped)
        if (-not $SkipExport -and $Mode -eq 'Backup') {
            $timestamp = Get-Date -Format 'yyyyMMdd_HHmmss'
            $exportFile = Join-Path $BackupDir "full\${DistroName}_${timestamp}.tar"

            Export-WSLDistribution -Name $DistroName -Destination $exportFile
        }
        else {
            Write-Log "Skipping full WSL export" -Level Info
        }

        # Start WSL distribution for incremental backup
        Start-WSLDistribution -Name $DistroName

        # Run WSL backup script
        Invoke-WSLBackupScript -DistroName $DistroName -ScriptPath $BashScriptPath -Mode $Mode

        # Rotate old backups
        if ($Mode -eq 'Backup') {
            Remove-OldBackups -BackupPath $BackupDir -KeepCount 3
        }

        # Success notification
        Write-Log '==========================================' -Level Info
        Write-Log 'Backup completed successfully' -Level Success
        Write-Log "Log file: $LogFile" -Level Info
        Write-Log '==========================================' -Level Info

        Send-Notification -Title $NotificationTitle -Message "Backup completed successfully`nLog: $LogFile" -Type Info

        # Optionally restart WSL
        if (-not $NoRestart) {
            Write-Log "Restarting WSL distribution" -Level Info
            Start-WSLDistribution -Name $DistroName
        }

        exit 0
    }
    catch {
        Write-Log "Backup failed: $_" -Level Error
        Write-Log "Stack trace: $($_.ScriptStackTrace)" -Level Error

        Send-Notification -Title $NotificationTitle -Message "Backup failed: $_" -Type Error

        # Attempt to restart WSL even on failure
        try {
            Start-WSLDistribution -Name $DistroName
        }
        catch {
            Write-Log "Failed to restart WSL: $_" -Level Error
        }

        exit 1
    }
}

# Run main function
Main
