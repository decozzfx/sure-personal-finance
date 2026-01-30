#!/bin/bash

# ==============================================================================
# Sure Application Restore Script
# ==============================================================================
#
# This script restores backups of:
#   - PostgreSQL database (all financial data, transactions, accounts, users)
#   - Application storage (uploaded files, attachments, images)
#
# Usage:
#   ./restore.sh --help            # Show help message
#   ./restore.sh --list            # List available backups
#   ./restore.sh --db FILE         # Restore specific database backup
#   ./restore.sh --storage FILE     # Restore specific storage backup
#   ./restore.sh --all DB_FILE STORAGE_FILE  # Restore both database and storage
#
# WARNING: This script will overwrite existing data!
# ==============================================================================

set -e  # Exit on error

# ========================================
# Configuration
# ========================================

# Backup directory (relative to script location)
BACKUP_DIR="./backups"

# Database settings (must match docker-compose.yml)
DB_CONTAINER="sure-postgres"
DB_USER="sure_user"
DB_NAME="sure_production"

# Web container settings
WEB_CONTAINER="sure-web"
STORAGE_PATH="/rails/storage"

# Log file
LOG_FILE="./logs/restore.log"

# ========================================
# Functions
# ========================================

# Print usage information
show_help() {
    cat << EOF
Sure Application Restore Script

Usage: ./restore.sh [OPTIONS]

Options:
  --help                Show this help message
  --list                List all available backups
  --db FILE            Restore specific database backup
  --storage FILE        Restore specific storage backup
  --all DB_FILE STORAGE_FILE  Restore both database and storage
  --force               Skip confirmation prompts

Examples:
  ./restore.sh --list                                    # List available backups
  ./restore.sh --db backups/db_backup_20250129_020000.sql    # Restore database
  ./restore.sh --storage backups/storage_backup_20250129.tar.gz  # Restore storage
  ./restore.sh --all backups/db_backup_20250129.sql backups/storage_backup_20250129.tar.gz
  ./restore.sh --db backups/db_backup_latest.sql --force   # Restore without confirmation

WARNING: This will OVERWRITE existing data. Always backup before restoring!

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

# List all available backups
list_backups() {
    echo ""
    echo "==========================================="
    echo "Available Backups"
    echo "==========================================="
    echo ""

    # List database backups
    echo "Database Backups:"
    echo "---------------"
    if [ "$(find "$BACKUP_DIR" -name "db_backup_*.sql" 2>/dev/null | wc -l)" -eq 0 ]; then
        echo "No database backups found."
    else
        find "$BACKUP_DIR" -name "db_backup_*.sql" 2>/dev/null | sort -r | while read -r file; do
            local size=$(du -h "$file" | cut -f1)
            local date=$(stat -f "%Sm" -t "%Y-%m-%d %H:%M:%S" "$file" 2>/dev/null || stat -c "%y" "$file" 2>/dev/null | cut -d'.' -f1)
            echo "  $(basename "$file")"
            echo "    Size: $size | Date: $date"
        done
    fi
    echo ""

    # List storage backups
    echo "Storage Backups:"
    echo "---------------"
    if [ "$(find "$BACKUP_DIR" -name "storage_backup_*.tar.gz" 2>/dev/null | wc -l)" -eq 0 ]; then
        echo "No storage backups found."
    else
        find "$BACKUP_DIR" -name "storage_backup_*.tar.gz" 2>/dev/null | sort -r | while read -r file; do
            local size=$(du -h "$file" | cut -f1)
            local date=$(stat -f "%Sm" -t "%Y-%m-%d %H:%M:%S" "$file" 2>/dev/null || stat -c "%y" "$file" 2>/dev/null | cut -d'.' -f1)
            echo "  $(basename "$file")"
            echo "    Size: $size | Date: $date"
        done
    fi
    echo ""
}

# Confirm restore operation
confirm_restore() {
    local message="$1"

    if [ "$FORCE" = true ]; then
        log "WARNING" "Skipping confirmation (--force flag)"
        return
    fi

    echo ""
    echo "==========================================="
    echo "WARNING: This will OVERWRITE existing data!"
    echo "==========================================="
    echo ""
    echo "$message"
    echo ""
    read -p "Are you sure you want to continue? (yes/no): " answer

    if [ "$answer" != "yes" ] && [ "$answer" != "YES" ]; then
        log "INFO" "Restore operation cancelled by user"
        exit 0
    fi

    echo ""
}

# Backup current state before restore
backup_before_restore() {
    log "INFO" "Creating pre-restore backup..."

    local timestamp=$(date +%Y%m%d_%H%M%S)_pre_restore
    local backup_dir="$BACKUP_DIR/pre_restore"

    mkdir -p "$backup_dir"

    # Backup current database
    if docker compose exec -T db pg_dump -U "$DB_USER" "$DB_NAME" > "$backup_dir/db_pre_restore_$timestamp.sql" 2>&1; then
        log "SUCCESS" "Pre-restore database backup created"
    else
        log "WARNING" "Failed to create pre-restore database backup"
    fi

    # Backup current storage
    if docker compose exec -T web tar -czf - -C "$STORAGE_PATH" . > "$backup_dir/storage_pre_restore_$timestamp.tar.gz" 2>&1; then
        log "SUCCESS" "Pre-restore storage backup created"
    else
        log "WARNING" "Failed to create pre-restore storage backup"
    fi

    log "INFO" "Pre-restore backups saved to: $backup_dir"
}

# Restore database
restore_database() {
    local backup_file="$1"

    if [ ! -f "$backup_file" ]; then
        log "ERROR" "Database backup file not found: $backup_file"
        exit 1
    fi

    log "INFO" "Starting database restore from: $(basename "$backup_file")"

    # Stop web and worker to prevent conflicts
    log "INFO" "Stopping web and worker services..."
    docker compose stop web worker

    # Restore database
    if docker compose exec -T db psql -U "$DB_USER" "$DB_NAME" < "$backup_file" 2>&1; then
        log "SUCCESS" "Database restore completed"

        # Get database size
        local db_size=$(docker compose exec -T db psql -U "$DB_USER" -d "$DB_NAME" -c "SELECT pg_size_pretty(pg_database_size('$DB_NAME'));" 2>/dev/null | grep -v "pg_size_pretty" | xargs)
        log "INFO" "Database size: $db_size"
    else
        log "ERROR" "Database restore failed"
        docker compose start web worker
        exit 1
    fi

    # Start web and worker
    log "INFO" "Restarting web and worker services..."
    docker compose start web worker

    # Wait for services to be healthy
    log "INFO" "Waiting for services to be healthy..."
    sleep 10
}

# Restore storage
restore_storage() {
    local backup_file="$1"

    if [ ! -f "$backup_file" ]; then
        log "ERROR" "Storage backup file not found: $backup_file"
        exit 1
    fi

    log "INFO" "Starting storage restore from: $(basename "$backup_file")"

    # Stop web service
    log "INFO" "Stopping web service..."
    docker compose stop web

    # Clear existing storage
    log "INFO" "Clearing existing storage..."
    docker compose exec -T web rm -rf "$STORAGE_PATH"/* 2>/dev/null || true

    # Restore storage
    if docker compose exec -T web tar -xzf - -C "$STORAGE_PATH" < "$backup_file" 2>&1; then
        log "SUCCESS" "Storage restore completed"

        # Get storage size
        local storage_size=$(docker compose exec -T web du -sh "$STORAGE_PATH" 2>/dev/null | cut -f1)
        log "INFO" "Storage size: $storage_size"
    else
        log "ERROR" "Storage restore failed"
        docker compose start web
        exit 1
    fi

    # Start web service
    log "INFO" "Restarting web service..."
    docker compose start web

    # Wait for service to be healthy
    log "INFO" "Waiting for service to be healthy..."
    sleep 10
}

# Verify restore
verify_restore() {
    log "INFO" "Verifying restore..."

    # Check database
    if docker compose exec -T db psql -U "$DB_USER" -d "$DB_NAME" -c "SELECT 1;" &> /dev/null; then
        log "SUCCESS" "Database is accessible"
    else
        log "ERROR" "Database is not accessible"
        exit 1
    fi

    # Check web service
    if curl -f -s http://localhost:3010 &> /dev/null; then
        log "SUCCESS" "Web service is responding"
    else
        log "WARNING" "Web service is not responding (may take a moment)"
    fi
}

# Generate restore summary
show_summary() {
    echo ""
    echo "==========================================="
    log "INFO" "Restore Summary"
    echo "==========================================="
    echo ""
    log "SUCCESS" "Restore process completed successfully!"
    echo ""
    echo "Next steps:"
    echo "  1. Check application: http://localhost:3010"
    echo "  2. Review logs: docker compose logs -f"
    echo "  3. Verify data integrity"
    echo ""
    echo "Pre-restore backups saved to: $BACKUP_DIR/pre_restore/"
}

# ========================================
# Parse Arguments
# ========================================

FORCE=false
RESTORE_DB=""
RESTORE_STORAGE=""
LIST_ONLY=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --help)
            show_help
            ;;
        --list)
            LIST_ONLY=true
            shift
            ;;
        --db)
            RESTORE_DB="$2"
            shift 2
            ;;
        --storage)
            RESTORE_STORAGE="$2"
            shift 2
            ;;
        --all)
            RESTORE_DB="$2"
            RESTORE_STORAGE="$3"
            shift 3
            ;;
        --force)
            FORCE=true
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

log "INFO" "Starting restore process..."

# Pre-flight checks
check_docker
check_containers

# List backups only
if [ "$LIST_ONLY" = true ]; then
    list_backups
    exit 0
fi

# Validate arguments
if [ -z "$RESTORE_DB" ] && [ -z "$RESTORE_STORAGE" ]; then
    log "ERROR" "No backup specified. Use --db FILE or --storage FILE or --list to see available backups"
    show_help
fi

# List available backups
list_backups

# Confirm restore
confirm_restore "You are about to restore data from backups. This action cannot be undone!"

# Create pre-restore backup
backup_before_restore

# Restore database
if [ -n "$RESTORE_DB" ]; then
    restore_database "$RESTORE_DB"
fi

# Restore storage
if [ -n "$RESTORE_STORAGE" ]; then
    restore_storage "$RESTORE_STORAGE"
fi

# Verify restore
verify_restore

# Show summary
show_summary
