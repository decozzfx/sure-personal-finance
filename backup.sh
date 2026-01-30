#!/bin/bash

# ==============================================================================
# Sure Application Backup Script
# ==============================================================================
#
# This script creates automated backups of:
#   - PostgreSQL database (all financial data, transactions, accounts, users)
#   - Application storage (uploaded files, attachments, images)
#
# Usage:
#   ./backup.sh                    # Run backup with default settings
#   ./backup.sh --help             # Show help message
#
# Configuration:
#   Edit the variables below to customize backup behavior
# ==============================================================================

set -e  # Exit on error

# ========================================
# Configuration
# ========================================

# Backup directory (relative to script location)
BACKUP_DIR="./backups"

# Backup retention period (in days)
RETENTION_DAYS=7

# Compression level (1-9, higher = better compression but slower)
COMPRESSION_LEVEL=6

# Backup types (true/false)
BACKUP_DATABASE=true
BACKUP_STORAGE=true

# Database settings (must match docker-compose.yml)
DB_CONTAINER="sure-postgres"
DB_USER="sure_user"
DB_NAME="sure_production"

# Web container settings
WEB_CONTAINER="sure-web"
STORAGE_PATH="/rails/storage"

# Log file
LOG_FILE="./logs/backup.log"

# ========================================
# Functions
# ========================================

# Print usage information
show_help() {
    cat << EOF
Sure Application Backup Script

Usage: ./backup.sh [OPTIONS]

Options:
  --help                Show this help message
  --no-database         Skip database backup
  --no-storage           Skip storage backup
  --retention-days N     Set retention period (default: 7 days)
  --output-dir DIR       Set output directory (default: ./backups)
  --dry-run             Show what would be backed up without doing it

Examples:
  ./backup.sh                                    # Standard backup
  ./backup.sh --retention-days 30                 # Keep 30 days
  ./backup.sh --no-storage                        # Database only
  ./backup.sh --dry-run                          # Preview backup

EOF
    exit 0
}

# Log message with timestamp
log() {
    local level="$1"
    shift
    local message="$*"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] [$level] $message"
    echo "[$timestamp] [$level] $message" >> "$LOG_FILE" 2>/dev/null || true
}

# Check if Docker Compose is available
check_docker() {
    if ! command -v docker &> /dev/null; then
        log "ERROR" "Docker is not installed or not in PATH"
        exit 1
    fi

    if ! docker compose version &> /dev/null; then
        log "ERROR" "Docker Compose is not available"
        exit 1
    fi
}

# Check if containers are running
check_containers() {
    if ! docker ps | grep -q "$DB_CONTAINER"; then
        log "ERROR" "Database container '$DB_CONTAINER' is not running"
        exit 1
    fi

    if ! docker ps | grep -q "$WEB_CONTAINER"; then
        log "ERROR" "Web container '$WEB_CONTAINER' is not running"
        exit 1
    fi
}

# Create necessary directories
setup_directories() {
    mkdir -p "$BACKUP_DIR"
    mkdir -p "$(dirname "$LOG_FILE")"
    log "INFO" "Backup directory: $BACKUP_DIR"
}

# Get current timestamp
get_timestamp() {
    date +%Y%m%d_%H%M%S
}

# Backup database
backup_database() {
    if [ "$BACKUP_DATABASE" = false ]; then
        log "INFO" "Skipping database backup (--no-database flag)"
        return
    fi

    local timestamp=$(get_timestamp)
    local backup_file="$BACKUP_DIR/db_backup_$timestamp.sql"

    log "INFO" "Starting database backup..."

    if [ "$DRY_RUN" = true ]; then
        log "DRY-RUN" "Would backup database to: $backup_file"
        return
    fi

    # Perform backup using pg_dump
    if docker compose exec -T db pg_dump -U "$DB_USER" "$DB_NAME" > "$backup_file" 2>&1; then
        log "SUCCESS" "Database backup completed: $backup_file"
        log "INFO" "Database backup size: $(du -h "$backup_file" | cut -f1)"
    else
        log "ERROR" "Database backup failed"
        rm -f "$backup_file"
        exit 1
    fi
}

# Backup application storage
backup_storage() {
    if [ "$BACKUP_STORAGE" = false ]; then
        log "INFO" "Skipping storage backup (--no-storage flag)"
        return
    fi

    local timestamp=$(get_timestamp)
    local backup_file="$BACKUP_DIR/storage_backup_$timestamp.tar.gz"

    log "INFO" "Starting storage backup..."

    if [ "$DRY_RUN" = true ]; then
        log "DRY-RUN" "Would backup storage to: $backup_file"
        return
    fi

    # Perform backup using tar
    if docker compose exec -T web tar -czf - -C "$STORAGE_PATH" . > "$backup_file" 2>&1; then
        log "SUCCESS" "Storage backup completed: $backup_file"
        log "INFO" "Storage backup size: $(du -h "$backup_file" | cut -f1)"
    else
        log "ERROR" "Storage backup failed"
        rm -f "$backup_file"
        exit 1
    fi
}

# Clean old backups
cleanup_old_backups() {
    log "INFO" "Cleaning up backups older than $RETENTION_DAYS days..."

    if [ "$DRY_RUN" = true ]; then
        local db_count=$(find "$BACKUP_DIR" -name "*.sql" -mtime +$RETENTION_DAYS 2>/dev/null | wc -l)
        local storage_count=$(find "$BACKUP_DIR" -name "*.tar.gz" -mtime +$RETENTION_DAYS 2>/dev/null | wc -l)
        log "DRY-RUN" "Would remove $db_count old database backups"
        log "DRY-RUN" "Would remove $storage_count old storage backups"
        return
    fi

    # Remove old database backups
    local db_removed=$(find "$BACKUP_DIR" -name "db_backup_*.sql" -mtime +$RETENTION_DAYS -delete -print 2>/dev/null | wc -l)

    # Remove old storage backups
    local storage_removed=$(find "$BACKUP_DIR" -name "storage_backup_*.tar.gz" -mtime +$RETENTION_DAYS -delete -print 2>/dev/null | wc -l)

    if [ "$db_removed" -gt 0 ] || [ "$storage_removed" -gt 0 ]; then
        log "INFO" "Removed $db_removed database backups and $storage_removed storage backups"
    else
        log "INFO" "No old backups to remove"
    fi
}

# Generate backup summary
show_summary() {
    if [ "$DRY_RUN" = true ]; then
        echo ""
        log "INFO" "Backup preview completed (no changes made)"
        return
    fi

    echo ""
    echo "==========================================="
    log "INFO" "Backup Summary"
    echo "==========================================="

    # Count backups
    local db_count=$(find "$BACKUP_DIR" -name "db_backup_*.sql" 2>/dev/null | wc -l)
    local storage_count=$(find "$BACKUP_DIR" -name "storage_backup_*.tar.gz" 2>/dev/null | wc -l)
    local total_size=$(du -sh "$BACKUP_DIR" 2>/dev/null | cut -f1)

    echo "Database backups: $db_count"
    echo "Storage backups: $storage_count"
    echo "Total size: $total_size"
    echo "Retention: $RETENTION_DAYS days"
    echo ""
    log "SUCCESS" "Backup process completed successfully!"
}

# ========================================
# Parse Arguments
# ========================================

DRY_RUN=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --help)
            show_help
            ;;
        --no-database)
            BACKUP_DATABASE=false
            shift
            ;;
        --no-storage)
            BACKUP_STORAGE=false
            shift
            ;;
        --retention-days)
            RETENTION_DAYS="$2"
            shift 2
            ;;
        --output-dir)
            BACKUP_DIR="$2"
            shift 2
            ;;
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        *)
            log "ERROR" "Unknown option: $1"
            show_help
            ;;
    esac
done

# ========================================
# Main Execution
# ========================================

log "INFO" "Starting backup process..."

# Pre-flight checks
check_docker
check_containers
setup_directories

# Perform backups
backup_database
backup_storage

# Cleanup old backups
cleanup_old_backups

# Show summary
show_summary
