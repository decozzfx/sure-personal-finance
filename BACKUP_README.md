# Backup and Restore Scripts - Quick Reference

## Quick Start

### Setup (One-Time)
```bash
# Scripts are already executable
# Create necessary directories
mkdir -p backups logs
```

### Create Backup
```bash
# Simple backup (database + storage)
./backup.sh
```

### List Backups
```bash
# Show all available backups
./restore.sh --list
```

### Restore Backup
```bash
# Restore database
./restore.sh --db backups/db_backup_YYYYMMDD_HHMMSS.sql

# Restore storage
./restore.sh --storage backups/storage_backup_YYYYMMDD_HHMMSS.tar.gz

# Restore both
./restore.sh --all db_backup.sql storage_backup.tar.gz --force
```

---

## Common Commands

### Backup Options
```bash
# Database only
./backup.sh --no-storage

# Storage only
./backup.sh --no-database

# Keep 30 days instead of 7
./backup.sh --retention-days 30

# Preview without backing up
./backup.sh --dry-run

# Show help
./backup.sh --help
```

### Restore Options
```bash
# List available backups
./restore.sh --list

# Restore without confirmation
./restore.sh --db backups/db_backup_latest.sql --force

# Show help
./restore.sh --help
```

---

## What Gets Backed Up

### Database (`db_backup_*.sql`)
- ✅ Users and authentication
- ✅ Families and members
- ✅ All accounts (bank, credit cards, investments, crypto, loans, etc.)
- ✅ All transactions and entries
- ✅ Categories and tags
- ✅ Balances and historical data
- ✅ Exchange rates

### Storage (`storage_backup_*.tar.gz`)
- ✅ Uploaded files
- ✅ Profile images
- ✅ Document attachments
- ✅ Exported files

---

## Automated Backups (Cron)

### Linux/macOS
```bash
# Edit crontab
crontab -e

# Add daily backup at 2 AM
0 2 * * * /path/to/sure/backup.sh >> /var/log/sure-backup.log 2>&1
```

---

## Off-Site Backups

### AWS S3
```bash
# After backup
./backup.sh && aws s3 sync backups/ s3://your-bucket/sure-backups/
```

### Google Cloud Storage
```bash
# After backup
./backup.sh && gsutil rsync backups/ gs://your-bucket/sure-backups/
```

---

## Troubleshooting

### Check backup logs
```bash
tail -f logs/backup.log
```

### Check restore logs
```bash
tail -f logs/restore.log
```

### Check disk space
```bash
df -h
du -sh backups/
```

### View Docker status
```bash
docker compose ps
docker compose logs -f
```

---

## Documentation

For detailed information, see: [docs/BACKUP_RESTORE.md](docs/BACKUP_RESTORE.md)

---

## Important Notes

⚠️ **Restoring will OVERWRITE existing data** - scripts create automatic pre-restore backups

✅ **Always backup before major changes** (upgrades, migrations, config changes)

🔒 **Keep `.env` and backup files secure** - never commit to version control

📊 **Test your backups monthly** to ensure they work when needed

💾 **Follow 3-2-1 rule**: 3 copies, 2 storage types, 1 off-site backup
