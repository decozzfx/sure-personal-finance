# Backup and Restore Guide

This guide provides comprehensive instructions for backing up and restoring your Sure personal finance application.

## Table of Contents

1. [Quick Start](#quick-start)
2. [Backup Operations](#backup-operations)
3. [Restore Operations](#restore-operations)
4. [Backup Strategy](#backup-strategy)
5. [Off-Site Backups](#off-site-backups)
6. [Troubleshooting](#troubleshooting)
7. [Best Practices](#best-practices)

---

## Quick Start

### Setup (One-Time)

```bash
# Make scripts executable
chmod +x backup.sh restore.sh

# Create necessary directories
mkdir -p backups logs
```

### Create Your First Backup

```bash
# Simple backup (database + storage)
./backup.sh
```

### List Available Backups

```bash
# List all backups
./restore.sh --list
```

### Restore from Backup

```bash
# Restore database
./restore.sh --db backups/db_backup_YYYYMMDD_HHMMSS.sql

# Restore storage
./restore.sh --storage backups/storage_backup_YYYYMMDD_HHMMSS.tar.gz
```

---

## Backup Operations

### Basic Backup

```bash
# Default backup (database + storage, 7-day retention)
./backup.sh
```

### Backup Options

```bash
# Backup only database (skip storage)
./backup.sh --no-storage

# Backup only storage (skip database)
./backup.sh --no-database

# Keep backups for 30 days instead of 7
./backup.sh --retention-days 30

# Preview what would be backed up (dry run)
./backup.sh --dry-run

# Show all options
./backup.sh --help
```

### Automated Backups (Cron)

#### Linux/macOS:

```bash
# Edit crontab
crontab -e

# Add daily backup at 2 AM
0 2 * * * /path/to/sure/backup.sh >> /var/log/sure-backup.log 2>&1

# Add weekly backup on Sunday at 3 AM
0 3 * * 0 /path/to/sure/backup.sh --retention-days 30 >> /var/log/sure-backup.log 2>&1
```

#### Windows (Task Scheduler):

1. Open Task Scheduler
2. Create Basic Task
3. Set trigger: Daily at 2:00 AM
4. Action: Start a program
5. Program: `bash.exe`
6. Arguments: `-c "cd /c/path/to/sure && ./backup.sh"`

---

## Restore Operations

### List Available Backups

```bash
# Show all available backups
./restore.sh --list
```

### Restore Database

```bash
# Restore specific database backup
./restore.sh --db backups/db_backup_20250129_020000.sql

# Restore without confirmation prompt
./restore.sh --db backups/db_backup_latest.sql --force
```

### Restore Storage

```bash
# Restore specific storage backup
./restore.sh --storage backups/storage_backup_20250129_020000.tar.gz

# Restore without confirmation prompt
./restore.sh --storage backups/storage_backup_latest.tar.gz --force
```

### Restore Both Database and Storage

```bash
# Restore both components
./restore.sh --all \
  backups/db_backup_20250129_020000.sql \
  backups/storage_backup_20250129_020000.tar.gz

# Restore without confirmation
./restore.sh --all \
  backups/db_backup_20250129_020000.sql \
  backups/storage_backup_20250129_020000.tar.gz \
  --force
```

### Restore Workflow

1. **Before restoring**, the script automatically creates a pre-restore backup
2. **Services are stopped** during restore to prevent conflicts
3. **Data is restored** from the specified backup file
4. **Services are restarted** and health is verified
5. **Pre-restore backups** are saved to `backups/pre_restore/` for safety

---

## Backup Strategy

### What Gets Backed Up

#### Database (`db_backup_*.sql`)
- **Users and authentication data**
- **Families and member relationships**
- **All accounts** (bank accounts, credit cards, investments, crypto, loans, etc.)
- **Transactions and entries**
- **Categories and tags**
- **Rules and configurations**
- **Balances and historical data**
- **Exchange rates**
- **Sync records and import data**

#### Storage (`storage_backup_*.tar.gz`)
- **Uploaded files**
- **Profile images**
- **Document attachments**
- **Exported files**
- **Application-generated files**

### Backup Retention

Default: **7 days**

You can customize retention:

```bash
# Keep backups for 30 days
./backup.sh --retention-days 30

# Keep backups for 90 days
./backup.sh --retention-days 90
```

### Backup Frequency Recommendations

#### Personal Use (1-3 users)
- **Daily backups** - Recommended
- **Weekly full backups** - Keep 30 days
- **Monthly archives** - Keep 12 months

#### Small Family (3-10 users)
- **Daily backups** - Required
- **Weekly full backups** - Keep 60 days
- **Monthly archives** - Keep 24 months

#### Large Family/Team (10+ users)
- **Daily backups** - Required
- **Hourly snapshots** - During active periods
- **Weekly full backups** - Keep 90 days
- **Monthly archives** - Keep 36 months

---

## Off-Site Backups

For production deployments, you should store backups off-site for disaster recovery.

### AWS S3

```bash
# Install AWS CLI
# https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html

# Configure AWS credentials
aws configure

# Sync backups to S3
aws s3 sync backups/ s3://your-bucket/sure-backups/

# Automate with cron
0 2 * * * /path/to/sure/backup.sh && aws s3 sync backups/ s3://your-bucket/sure-backups/
```

### Google Cloud Storage

```bash
# Install Google Cloud SDK
# https://cloud.google.com/sdk/docs/install

# Authenticate
gcloud auth login

# Sync backups to GCS
gsutil rsync backups/ gs://your-bucket/sure-backups/

# Automate with cron
0 2 * * * /path/to/sure/backup.sh && gsutil rsync backups/ gs://your-bucket/sure-backups/
```

### Backblaze B2

```bash
# Install B2 CLI
# https://www.backblaze.com/b2/docs/quick_command_line

# Authorize
b2 authorize-account

# Sync backups to B2
b2 sync backups/ b2://your-bucket/sure-backups/

# Automate with cron
0 2 * * * /path/to/sure/backup.sh && b2 sync backups/ b2://your-bucket/sure-backups/
```

### VPS Provider Snapshots

#### DigitalOcean
- **Cost:** 20% extra on base price
- **Features:** Automated daily snapshots, 7-day retention
- **Setup:** Enable in control panel

#### Hetzner
- **Cost:** ~€1.20/month per 100GB
- **Features:** Manual and automated snapshots
- **Setup:** Use `hcloud` CLI or web interface

#### Linode
- **Cost:** $2-5/month depending on plan
- **Features:** Automatic backups, 3 snapshots retained
- **Setup:** Enable in Linode Manager

---

## Troubleshooting

### Backup Issues

#### "Docker is not installed or not in PATH"
```bash
# Verify Docker is installed
docker --version
docker compose version

# If not installed, install Docker
# https://docs.docker.com/engine/install/
```

#### "Database container is not running"
```bash
# Check container status
docker compose ps

# Restart services
docker compose up -d

# Check logs
docker compose logs db
```

#### "Permission denied" when running scripts
```bash
# Make scripts executable
chmod +x backup.sh restore.sh
```

#### "No space left on device"
```bash
# Check disk usage
df -h

# Clean old backups
find backups/ -name "*.sql" -mtime +7 -delete
find backups/ -name "*.tar.gz" -mtime +7 -delete

# Clean Docker
docker system prune -a
```

### Restore Issues

#### "Backup file not found"
```bash
# List available backups
./restore.sh --list

# Verify file exists
ls -lh backups/
```

#### "Database restore failed"
```bash
# Check database container logs
docker compose logs db

# Test database connection
docker compose exec db psql -U sure_user sure_production -c "SELECT 1;"

# Verify backup file integrity
head -n 20 backups/db_backup_*.sql
```

#### "Storage restore failed"
```bash
# Check web container logs
docker compose logs web

# Verify storage path
docker compose exec web ls -lh /rails/storage

# Verify backup file integrity
tar -tzf backups/storage_backup_*.tar.gz
```

#### Application not responding after restore
```bash
# Restart all services
docker compose restart

# Check health status
docker compose ps

# View logs
docker compose logs -f

# Wait 30-60 seconds for services to fully start
```

### Data Integrity Issues

#### Verify database restore
```bash
# Check user count
docker compose exec db psql -U sure_user sure_production -c "SELECT COUNT(*) FROM users;"

# Check account count
docker compose exec db psql -U sure_user sure_production -c "SELECT COUNT(*) FROM accounts;"

# Check transaction count
docker compose exec db psql -U sure_user sure_production -c "SELECT COUNT(*) FROM transactions;"
```

#### Verify storage restore
```bash
# Check storage directory
docker compose exec web ls -lh /rails/storage/

# Count files
docker compose exec web find /rails/storage -type f | wc -l
```

---

## Best Practices

### 1. Follow the 3-2-1 Rule

- **3 copies** of your data:
  - Production database/storage
  - Local backup
  - Off-site backup (cloud storage)

- **2 different storage types**:
  - Local disk
  - Cloud storage (S3, GCS, B2)

- **1 off-site backup**:
  - Away from your primary location
  - Different geographic region

### 2. Test Your Backups

**Monthly backup verification:**

```bash
# Restore to test database
docker compose exec db createdb -U sure_user sure_test_restore
docker compose exec -T db psql -U sure_user sure_test_restore < backups/db_backup_latest.sql

# Verify data
docker compose exec db psql -U sure_user sure_test_restore -c "SELECT COUNT(*) FROM users;"

# Clean up
docker compose exec db dropdb -U sure_user sure_test_restore
```

### 3. Monitor Backup Logs

```bash
# View backup log
tail -f logs/backup.log

# View restore log
tail -f logs/restore.log

# Check for errors
grep "ERROR" logs/backup.log
grep "ERROR" logs/restore.log
```

### 4. Document Your Backup Procedure

Keep a backup.md file with:

- Backup locations
- Retention policies
- Off-site backup credentials
- Restore procedures
- Emergency contacts

### 5. Secure Your Backups

```bash
# Encrypt sensitive backups
gpg --encrypt --recipient your@email.com backups/db_backup_*.sql

# Decrypt when needed
gpg --decrypt backups/db_backup_*.sql.gpg > db_backup_decrypted.sql
```

### 6. Regular Maintenance

```bash
# Clean old backups monthly
find backups/ -name "*.sql" -mtime +30 -delete
find backups/ -name "*.tar.gz" -mtime +30 -delete

# Check disk space weekly
df -h

# Review logs monthly
tail -100 logs/backup.log
tail -100 logs/restore.log
```

### 7. Backup Before Major Changes

Always backup before:
- Upgrading the application
- Running migrations
- Making significant configuration changes
- Testing new features
- Deploying to production

```bash
# Quick backup before changes
./backup.sh

# Then proceed with changes
docker compose pull
docker compose up -d
```

### 8. Use Version Tags for Backups

```bash
# Backup before version upgrade
./backup.sh --retention-days 30
# Manual tag: mv backups/db_backup_YYYYMMDD.sql backups/db_backup_v1.2.0_before_upgrade.sql
```

---

## Advanced Backup Strategies

### Incremental Backups (Future Enhancement)

For large datasets, consider:
- PostgreSQL WAL archiving
- Point-in-time recovery (PITR)
- Differential backups

### Backup Rotation

```bash
# Hourly backups (keep 24 hours)
0 * * * * /path/to/sure/backup.sh --retention-days 1

# Daily backups (keep 7 days)
0 2 * * * /path/to/sure/backup.sh --retention-days 7

# Weekly backups (keep 4 weeks)
0 3 * * 0 /path/to/sure/backup.sh --retention-days 30

# Monthly backups (keep 12 months)
0 4 1 * * /path/to/sure/backup.sh --retention-days 365
```

### Cross-Region Replication

For critical data:
- Replicate backups to multiple cloud regions
- Use different providers for redundancy
- Implement failover procedures

---

## Quick Reference

### Backup Commands

```bash
# Standard backup
./backup.sh

# Database only
./backup.sh --no-storage

# Storage only
./backup.sh --no-database

# Custom retention
./backup.sh --retention-days 30

# Preview
./backup.sh --dry-run

# Help
./backup.sh --help
```

### Restore Commands

```bash
# List backups
./restore.sh --list

# Restore database
./restore.sh --db backups/db_backup_YYYYMMDD.sql

# Restore storage
./restore.sh --storage backups/storage_backup_YYYYMMDD.tar.gz

# Restore both
./restore.sh --all db.sql storage.tar.gz

# Force restore (no confirmation)
./restore.sh --db backups/db_backup_*.sql --force

# Help
./restore.sh --help
```

### Utility Commands

```bash
# Check backup size
du -sh backups/

# List backups
ls -lh backups/

# Clean old backups
find backups/ -name "*.sql" -mtime +7 -delete
find backups/ -name "*.tar.gz" -mtime +7 -delete

# View logs
tail -f logs/backup.log
tail -f logs/restore.log

# Check Docker status
docker compose ps

# View Docker logs
docker compose logs -f
```

---

## Support

If you encounter issues:

1. Check the [troubleshooting section](#troubleshooting) above
2. Review logs: `logs/backup.log` and `logs/restore.log`
3. Check Docker status: `docker compose ps`
4. Verify disk space: `df -h`
5. Open a discussion in the [GitHub repository](https://github.com/we-promise/sure/discussions)

---

## Security Reminders

- **Never commit** `.env` files or backup files to version control
- **Encrypt backups** containing sensitive financial data
- **Use strong passwords** for all services
- **Regularly review** backup logs for errors
- **Monitor disk usage** to prevent full disk scenarios
- **Keep backup scripts** and documentation up to date
- **Test restores** regularly to ensure backups work
