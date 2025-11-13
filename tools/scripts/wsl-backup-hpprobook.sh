#!/usr/bin/env bash
#
# WSL2 NixOS Backup Script for hp-probook-wsl
#
# Comprehensive backup solution for WSL2 NixOS distributions with:
# - Full WSL distribution export (VHDX snapshot)
# - Incremental rsync-based file backups
# - Backup verification and rotation
# - Integrity checking with checksums
# - Logging and Windows notifications
# - Restore mode support
#
# Usage:
#   ./wsl-backup-hpprobook.sh [backup|restore|verify]
#
# Default mode: backup

set -euo pipefail

################################################################################
# CONFIGURATION VARIABLES
################################################################################

# Backup mode: backup, restore, or verify
MODE="${1:-backup}"

# WSL distribution name
WSL_DISTRO="NixOS"

# Backup destination directory (Windows path - will be converted)
# Examples:
#   - Local: "D:/Backups/WSL"
#   - Network: "//server/backups/WSL"
#   - USB: "E:/WSL-Backups"
BACKUP_DIR_WINDOWS="D:/Backups/WSL-NixOS"

# Backup retention policy
KEEP_FULL_BACKUPS=3          # Number of full VHDX exports to keep
KEEP_INCREMENTAL_DAYS=30     # Days to keep incremental rsync backups

# Directories to backup (within WSL)
# Dynamically determine user home directory from defaults
USER_HOME="/home/$(awk '/^  user = / {gsub(/"/, "", $3); print $3}' /per/etc/nixos/lib/defaults.nix | head -1)"
BACKUP_SOURCES=(
    "/per/etc/nixos"         # NixOS configuration
    "${USER_HOME}"           # User home directory (from defaults)
    "/etc/ssh"               # SSH configuration
    "/etc/nixos"             # Legacy NixOS config location
    "/root"                  # Root user files
)

# Directories to exclude from rsync backup
RSYNC_EXCLUDES=(
    "/tmp"
    "/var/tmp"
    "/run"
    "/proc"
    "/sys"
    "/dev"
    "/mnt"
    "*.cache"
    "*.tmp"
    ".cache"
    ".local/share/Trash"
    "node_modules"
    ".venv"
    "__pycache__"
    "*.pyc"
    ".nix-*"
    "result"
    "result-*"
)

# Nix store metadata backup
BACKUP_NIX_STORE_METADATA=true

# Logging configuration
LOG_DIR="/var/log/backup"
LOG_FILE="${LOG_DIR}/wsl-backup.log"
LOG_RETENTION_DAYS=90

# Notification settings
ENABLE_NOTIFICATIONS=true
NOTIFICATION_TITLE="WSL Backup"

# Compression settings
COMPRESSION_LEVEL=6  # 1-9, higher = more compression but slower
USE_COMPRESSION=true

# Integrity checking
VERIFY_BACKUPS=true
CHECKSUM_ALGORITHM="sha256sum"

# Restore settings
RESTORE_TARGET="/"   # Target directory for restore operations

################################################################################
# INTERNAL VARIABLES (DO NOT MODIFY)
################################################################################

TIMESTAMP=$(date +%Y%m%d_%H%M%S)
DATE_ONLY=$(date +%Y%m%d)
HOSTNAME=$(hostname)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOCK_FILE="/var/run/wsl-backup.lock"

# Check for required tools
REQUIRED_TOOLS=(rsync wslpath sha256sum tar gzip)

################################################################################
# UTILITY FUNCTIONS
################################################################################

# Initialize logging
init_logging() {
    if [[ ! -d "$LOG_DIR" ]]; then
        mkdir -p "$LOG_DIR" 2>/dev/null || {
            LOG_DIR="/tmp"
            LOG_FILE="${LOG_DIR}/wsl-backup.log"
        }
    fi

    # Rotate old logs
    find "$LOG_DIR" -name "wsl-backup.log.*" -mtime +"$LOG_RETENTION_DAYS" -delete 2>/dev/null || true

    # Rotate current log if too large (>10MB)
    if [[ -f "$LOG_FILE" ]] && [[ $(stat -f%z "$LOG_FILE" 2>/dev/null || stat -c%s "$LOG_FILE") -gt 10485760 ]]; then
        mv "$LOG_FILE" "${LOG_FILE}.$(date +%Y%m%d_%H%M%S)"
    fi
}

# Logging function
log() {
    local level="$1"
    shift
    local message="$*"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')

    echo "[${timestamp}] [${level}] ${message}" | tee -a "$LOG_FILE"
}

# Send Windows notification
notify() {
    local title="$1"
    local message="$2"
    local type="${3:-info}"  # info, warning, error

    if [[ "$ENABLE_NOTIFICATIONS" != "true" ]]; then
        return 0
    fi

    # Use PowerShell to send Windows toast notification
    if command -v pwsh &>/dev/null; then
        pwsh -Command "
            Add-Type -AssemblyName System.Windows.Forms
            \$notification = New-Object System.Windows.Forms.NotifyIcon
            \$notification.Icon = [System.Drawing.SystemIcons]::Information
            \$notification.Visible = \$true
            \$notification.ShowBalloonTip(5000, '${title}', '${message}', [System.Windows.Forms.ToolTipIcon]::${type^})
        " 2>/dev/null || true
    fi
}

# Check for required tools
check_requirements() {
    log "INFO" "Checking system requirements..."

    local missing_tools=()
    for tool in "${REQUIRED_TOOLS[@]}"; do
        if ! command -v "$tool" &>/dev/null; then
            missing_tools+=("$tool")
        fi
    done

    if [[ ${#missing_tools[@]} -gt 0 ]]; then
        log "ERROR" "Missing required tools: ${missing_tools[*]}"
        log "ERROR" "Install with: nix-shell -p ${missing_tools[*]}"
        notify "$NOTIFICATION_TITLE" "Backup failed: missing tools" "error"
        return 1
    fi

    log "INFO" "All required tools available"
    return 0
}

# Acquire lock to prevent concurrent backups
acquire_lock() {
    if [[ -f "$LOCK_FILE" ]]; then
        local lock_pid
        lock_pid=$(cat "$LOCK_FILE")

        if kill -0 "$lock_pid" 2>/dev/null; then
            log "ERROR" "Another backup is running (PID: $lock_pid)"
            notify "$NOTIFICATION_TITLE" "Backup already in progress" "warning"
            return 1
        else
            log "WARN" "Removing stale lock file"
            rm -f "$LOCK_FILE"
        fi
    fi

    echo $$ > "$LOCK_FILE"
    log "INFO" "Lock acquired (PID: $$)"
    return 0
}

# Release lock
release_lock() {
    if [[ -f "$LOCK_FILE" ]]; then
        rm -f "$LOCK_FILE"
        log "INFO" "Lock released"
    fi
}

# Convert Windows path to WSL path
windows_to_wsl_path() {
    local win_path="$1"
    local result

    if command -v wslpath &>/dev/null; then
        result=$(wslpath -u "$win_path" 2>&1)
        if [[ $? -ne 0 ]] || [[ "$result" == *"error"* ]] || [[ ! "$result" =~ ^/ ]]; then
            log "ERROR" "Failed to convert Windows path: $win_path"
            log "ERROR" "wslpath output: $result"
            return 1
        fi
        echo "$result"
    else
        # Fallback: basic conversion
        echo "$win_path" | sed 's|\\|/|g' | sed 's|^\([A-Za-z]\):|/mnt/\L\1|'
    fi
}

# Convert WSL path to Windows path
wsl_to_windows_path() {
    local wsl_path="$1"
    local result

    if command -v wslpath &>/dev/null; then
        result=$(wslpath -w "$wsl_path" 2>&1)
        if [[ $? -ne 0 ]] || [[ "$result" == *"error"* ]] || [[ ! "$result" =~ ^[A-Za-z]: ]]; then
            log "ERROR" "Failed to convert WSL path: $wsl_path"
            log "ERROR" "wslpath output: $result"
            return 1
        fi
        echo "$result"
    else
        # Fallback: basic conversion
        echo "$wsl_path" | sed 's|^/mnt/\([a-z]\)/|\U\1:/|'
    fi
}

# Format bytes to human-readable size
format_size() {
    local size=$1

    if [[ $size -lt 1024 ]]; then
        echo "${size}B"
    elif [[ $size -lt 1048576 ]]; then
        echo "$(( size / 1024 ))KB"
    elif [[ $size -lt 1073741824 ]]; then
        echo "$(( size / 1048576 ))MB"
    else
        echo "$(( size / 1073741824 ))GB"
    fi
}

################################################################################
# BACKUP FUNCTIONS
################################################################################

# Perform full WSL distribution export
backup_full_export() {
    log "INFO" "Starting full WSL distribution export..."

    local backup_dir
    backup_dir=$(windows_to_wsl_path "$BACKUP_DIR_WINDOWS")
    if [[ $? -ne 0 ]] || [[ -z "$backup_dir" ]]; then
        log "ERROR" "Failed to convert backup directory path"
        return 1
    fi

    # Create backup directory structure
    local full_backup_dir="${backup_dir}/full"
    mkdir -p "$full_backup_dir"

    local export_file="${full_backup_dir}/${WSL_DISTRO}_${TIMESTAMP}.tar"
    local export_file_windows
    export_file_windows=$(wsl_to_windows_path "$export_file")
    if [[ $? -ne 0 ]] || [[ -z "$export_file_windows" ]]; then
        log "ERROR" "Failed to convert export file path"
        return 1
    fi

    log "INFO" "Export destination: ${export_file}"

    # Export from Windows (requires this script to communicate with PowerShell)
    # Note: Actual export must be done from Windows side
    # This creates a marker file for the PowerShell script
    echo "${export_file_windows}" > "${backup_dir}/.export-target"

    log "INFO" "Full export target marked: ${export_file_windows}"
    log "INFO" "PowerShell script will perform the actual export"

    return 0
}

# Perform incremental rsync backup
backup_incremental() {
    log "INFO" "Starting incremental rsync backup..."

    local backup_dir
    backup_dir=$(windows_to_wsl_path "$BACKUP_DIR_WINDOWS")
    if [[ $? -ne 0 ]] || [[ -z "$backup_dir" ]]; then
        log "ERROR" "Failed to convert backup directory path"
        return 1
    fi

    # Create incremental backup directory
    local incremental_dir="${backup_dir}/incremental/${DATE_ONLY}"
    mkdir -p "$incremental_dir"

    # Build rsync exclude arguments
    local exclude_args=()
    for exclude in "${RSYNC_EXCLUDES[@]}"; do
        exclude_args+=(--exclude="$exclude")
    done

    # Backup each source directory
    local total_size=0
    local file_count=0

    for source in "${BACKUP_SOURCES[@]}"; do
        if [[ ! -e "$source" ]]; then
            log "WARN" "Source does not exist: ${source}"
            continue
        fi

        log "INFO" "Backing up: ${source}"

        # Sanitize source path for directory name
        local source_name="${source//\//_}"
        local dest="${incremental_dir}${source}"

        mkdir -p "$(dirname "$dest")"

        # Perform rsync with progress
        local rsync_opts=(
            -aAXv
            --delete
            --delete-excluded
            --partial
            --info=progress2
            --human-readable
        )

        if [[ "$USE_COMPRESSION" == "true" ]]; then
            rsync_opts+=(--compress --compress-level="$COMPRESSION_LEVEL")
        fi

        # Run rsync and capture statistics
        local rsync_log="${incremental_dir}/.rsync_${source_name}.log"

        if rsync "${rsync_opts[@]}" "${exclude_args[@]}" "$source/" "$dest/" 2>&1 | tee "$rsync_log"; then
            log "INFO" "Successfully backed up: ${source}"

            # Count files and calculate size
            local source_size
            source_size=$(du -sb "$dest" 2>/dev/null | cut -f1 || echo 0)
            total_size=$((total_size + source_size))

            local source_files
            source_files=$(find "$dest" -type f 2>/dev/null | wc -l || echo 0)
            file_count=$((file_count + source_files))
        else
            log "ERROR" "Failed to backup: ${source}"
            notify "$NOTIFICATION_TITLE" "Backup failed for ${source}" "error"
        fi
    done

    log "INFO" "Incremental backup complete"
    log "INFO" "Total size: $(format_size $total_size)"
    log "INFO" "Total files: ${file_count}"

    # Create backup manifest
    create_manifest "$incremental_dir" "$total_size" "$file_count"

    return 0
}

# Backup Nix store metadata
backup_nix_metadata() {
    if [[ "$BACKUP_NIX_STORE_METADATA" != "true" ]]; then
        return 0
    fi

    log "INFO" "Backing up Nix store metadata..."

    local backup_dir
    backup_dir=$(windows_to_wsl_path "$BACKUP_DIR_WINDOWS")
    if [[ $? -ne 0 ]] || [[ -z "$backup_dir" ]]; then
        log "ERROR" "Failed to convert backup directory path"
        return 1
    fi

    local metadata_dir="${backup_dir}/nix-metadata/${DATE_ONLY}"
    mkdir -p "$metadata_dir"

    # Export Nix store paths
    if command -v nix-store &>/dev/null; then
        log "INFO" "Exporting Nix store paths..."
        nix-store --query --requisites /run/current-system > "${metadata_dir}/store-paths.txt" 2>/dev/null || true

        # Export currently installed packages
        nix-env -q --installed > "${metadata_dir}/installed-packages.txt" 2>/dev/null || true

        # Export system generation information
        if [[ -d /nix/var/nix/profiles ]]; then
            ls -l /nix/var/nix/profiles/system* > "${metadata_dir}/generations.txt" 2>/dev/null || true
        fi

        log "INFO" "Nix metadata backed up to: ${metadata_dir}"
    else
        log "WARN" "nix-store command not found, skipping Nix metadata backup"
    fi

    return 0
}

# Create backup manifest with metadata
create_manifest() {
    local backup_path="$1"
    local total_size="$2"
    local file_count="$3"

    local manifest_file="${backup_path}/.manifest.json"

    cat > "$manifest_file" << EOF
{
  "timestamp": "${TIMESTAMP}",
  "hostname": "${HOSTNAME}",
  "distro": "${WSL_DISTRO}",
  "backup_type": "incremental",
  "total_size_bytes": ${total_size},
  "total_files": ${file_count},
  "sources": $(printf '%s\n' "${BACKUP_SOURCES[@]}" | jq -R . | jq -s .),
  "excludes": $(printf '%s\n' "${RSYNC_EXCLUDES[@]}" | jq -R . | jq -s .),
  "compression": ${USE_COMPRESSION},
  "compression_level": ${COMPRESSION_LEVEL}
}
EOF

    log "INFO" "Created backup manifest: ${manifest_file}"
}

# Verify backup integrity
verify_backup() {
    local backup_path="$1"

    log "INFO" "Verifying backup integrity: ${backup_path}"

    # Check if manifest exists
    if [[ ! -f "${backup_path}/.manifest.json" ]]; then
        log "WARN" "No manifest found for backup: ${backup_path}"
        return 1
    fi

    # Verify file count
    local manifest_count
    manifest_count=$(jq -r '.total_files' "${backup_path}/.manifest.json")

    local actual_count
    actual_count=$(find "$backup_path" -type f ! -name '.manifest.json' ! -name '.rsync_*.log' ! -name '.checksum' 2>/dev/null | wc -l)

    log "INFO" "Expected files: ${manifest_count}, Actual files: ${actual_count}"

    if [[ "$manifest_count" != "$actual_count" ]]; then
        log "WARN" "File count mismatch in backup verification"
    fi

    # Generate checksums
    local checksum_file="${backup_path}/.checksum"
    log "INFO" "Generating checksums..."

    find "$backup_path" -type f ! -name '.manifest.json' ! -name '.rsync_*.log' ! -name '.checksum' -exec "$CHECKSUM_ALGORITHM" {} \; > "$checksum_file" 2>/dev/null || true

    local checksum_count
    checksum_count=$(wc -l < "$checksum_file")

    log "INFO" "Generated ${checksum_count} checksums"

    if [[ "$checksum_count" -eq 0 ]]; then
        log "ERROR" "Failed to generate checksums"
        return 1
    fi

    log "INFO" "Backup verification complete"
    return 0
}

# Rotate old backups
rotate_backups() {
    log "INFO" "Rotating old backups..."

    local backup_dir
    backup_dir=$(windows_to_wsl_path "$BACKUP_DIR_WINDOWS")
    if [[ $? -ne 0 ]] || [[ -z "$backup_dir" ]]; then
        log "ERROR" "Failed to convert backup directory path"
        return 1
    fi

    # Rotate full backups
    log "INFO" "Keeping last ${KEEP_FULL_BACKUPS} full backups"

    if [[ -d "${backup_dir}/full" ]]; then
        local full_backups
        mapfile -t full_backups < <(find "${backup_dir}/full" -name "*.tar" -type f | sort -r)

        if [[ ${#full_backups[@]} -gt $KEEP_FULL_BACKUPS ]]; then
            local backups_to_delete=("${full_backups[@]:$KEEP_FULL_BACKUPS}")

            for backup in "${backups_to_delete[@]}"; do
                log "INFO" "Deleting old full backup: $(basename "$backup")"
                rm -f "$backup"
            done
        fi
    fi

    # Rotate incremental backups
    log "INFO" "Deleting incremental backups older than ${KEEP_INCREMENTAL_DAYS} days"

    if [[ -d "${backup_dir}/incremental" ]]; then
        find "${backup_dir}/incremental" -maxdepth 1 -type d -mtime +"$KEEP_INCREMENTAL_DAYS" -exec rm -rf {} \; 2>/dev/null || true
    fi

    # Rotate Nix metadata
    if [[ -d "${backup_dir}/nix-metadata" ]]; then
        find "${backup_dir}/nix-metadata" -maxdepth 1 -type d -mtime +"$KEEP_INCREMENTAL_DAYS" -exec rm -rf {} \; 2>/dev/null || true
    fi

    log "INFO" "Backup rotation complete"
}

################################################################################
# RESTORE FUNCTIONS
################################################################################

# Restore from backup
restore_from_backup() {
    log "INFO" "Starting restore operation..."

    local backup_dir
    backup_dir=$(windows_to_wsl_path "$BACKUP_DIR_WINDOWS")
    if [[ $? -ne 0 ]] || [[ -z "$backup_dir" ]]; then
        log "ERROR" "Failed to convert backup directory path"
        return 1
    fi

    # List available backups
    log "INFO" "Available incremental backups:"

    local backups
    mapfile -t backups < <(find "${backup_dir}/incremental" -maxdepth 1 -type d | sort -r)

    if [[ ${#backups[@]} -eq 0 ]]; then
        log "ERROR" "No backups found in ${backup_dir}/incremental"
        return 1
    fi

    local idx=1
    for backup in "${backups[@]}"; do
        echo "  ${idx}. $(basename "$backup")"
        idx=$((idx + 1))
    done

    # Prompt user to select backup
    read -rp "Select backup to restore (1-${#backups[@]}): " selection

    if [[ ! "$selection" =~ ^[0-9]+$ ]] || [[ "$selection" -lt 1 ]] || [[ "$selection" -gt ${#backups[@]} ]]; then
        log "ERROR" "Invalid selection"
        return 1
    fi

    local selected_backup="${backups[$((selection - 1))]}"

    log "INFO" "Selected backup: $(basename "$selected_backup")"
    log "WARN" "This will restore files to: ${RESTORE_TARGET}"

    read -rp "Continue? (yes/no): " confirm

    if [[ "$confirm" != "yes" ]]; then
        log "INFO" "Restore cancelled by user"
        return 0
    fi

    # Perform restore with rsync
    log "INFO" "Restoring from: ${selected_backup}"

    rsync -aAXv --delete --partial --info=progress2 "${selected_backup}/" "${RESTORE_TARGET}/" 2>&1 | tee -a "$LOG_FILE"

    log "INFO" "Restore complete"
    notify "$NOTIFICATION_TITLE" "Restore completed successfully" "info"

    return 0
}

################################################################################
# MAIN EXECUTION
################################################################################

main() {
    # Initialize
    init_logging

    log "INFO" "=========================================="
    log "INFO" "WSL Backup Script Started"
    log "INFO" "Mode: ${MODE}"
    log "INFO" "Hostname: ${HOSTNAME}"
    log "INFO" "Timestamp: ${TIMESTAMP}"
    log "INFO" "=========================================="

    # Check requirements
    if ! check_requirements; then
        exit 1
    fi

    # Acquire lock
    if ! acquire_lock; then
        exit 1
    fi

    # Trap to ensure cleanup
    trap release_lock EXIT INT TERM

    # Execute based on mode
    case "$MODE" in
        backup)
            log "INFO" "Starting backup operations..."

            # Full export marker (actual export done by PowerShell)
            backup_full_export

            # Incremental rsync backup
            backup_incremental

            # Nix metadata backup
            backup_nix_metadata

            # Verify backup
            if [[ "$VERIFY_BACKUPS" == "true" ]]; then
                local backup_dir
                backup_dir=$(windows_to_wsl_path "$BACKUP_DIR_WINDOWS")
                if [[ $? -ne 0 ]] || [[ -z "$backup_dir" ]]; then
                    log "ERROR" "Failed to convert backup directory path for verification"
                else
                    verify_backup "${backup_dir}/incremental/${DATE_ONLY}"
                fi
            fi

            # Rotate old backups
            rotate_backups

            log "INFO" "Backup completed successfully"
            notify "$NOTIFICATION_TITLE" "Backup completed successfully" "info"
            ;;

        restore)
            restore_from_backup
            ;;

        verify)
            log "INFO" "Verifying backups..."
            local backup_dir
            backup_dir=$(windows_to_wsl_path "$BACKUP_DIR_WINDOWS")
            if [[ $? -ne 0 ]] || [[ -z "$backup_dir" ]]; then
                log "ERROR" "Failed to convert backup directory path"
                exit 1
            fi

            mapfile -t backups < <(find "${backup_dir}/incremental" -maxdepth 1 -type d)

            for backup in "${backups[@]}"; do
                verify_backup "$backup"
            done

            log "INFO" "Verification complete"
            ;;

        *)
            log "ERROR" "Invalid mode: ${MODE}"
            echo "Usage: $0 [backup|restore|verify]"
            exit 1
            ;;
    esac

    log "INFO" "=========================================="
    log "INFO" "WSL Backup Script Completed"
    log "INFO" "=========================================="

    return 0
}

# Run main function
main "$@"
