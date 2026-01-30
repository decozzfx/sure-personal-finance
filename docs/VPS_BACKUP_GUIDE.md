# VPS Deployment with Backups Guide

Complete guide for deploying Sure on a VPS with automated backup and restore procedures.

## Table of Contents

1. [VPS Prerequisites](#vps-prerequisites)
2. [Initial Setup](#initial-setup)
3. [Configure Backups](#configure-backups)
4. [Off-Site Backup Strategy](#off-site-backup-strategy)
5. [Monitoring and Alerts](#monitoring-and-alerts)
6. [Disaster Recovery](#disaster-recovery)
7. [Maintenance](#maintenance)

---

## VPS Prerequisites

### Recommended VPS Specifications

**Minimum Viable:**
- CPU: 1-2 vCPU
- RAM: 2 GB
- Storage: 20 GB SSD
- Bandwidth: 1 TB/month
- Cost: ~$5-10/month

**Recommended:**
- CPU: 2 vCPU
- RAM: 4 GB
- Storage: 40 GB SSD
- Bandwidth: 2 TB/month
- Cost: ~$20/month

### Recommended VPS Providers

| Provider | Plan | Cost | Storage | Features |
|----------|-------|------|----------|----------|
| Hetzner | CX22 | €9.55/month | 40 GB SSD | Best value |
| DigitalOcean | Basic-4 | $24/month | 80 GB SSD | Excellent support |
| Linode | Nanode 4 | $20/month | 80 GB SSD | Good performance |

---

## Initial Setup

### 1. Server Setup

```bash
# Connect to your server
ssh root@YOUR_SERVER_IP

# Update system
apt update && apt upgrade -y

# Install essential packages
apt install -y curl wget git ufw fail2ban htop

# Install Docker
curl -fsSL https://get.docker.com -o get-docker.sh
sh get-docker.sh

# Install Docker Compose
curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose

# Configure firewall
ufw allow ssh
ufw allow 80
ufw allow 443
ufw --force enable

# Configure fail2ban
systemctl enable fail2ban
systemctl start fail2ban
```

### 2. Application Deployment

```bash
# Create application directory
mkdir -p /opt/sure
cd /opt/sure

# Copy docker-compose.yml (from your local machine)
# scp docker-compose.yml root@YOUR_SERVER_IP:/opt/sure/

# Copy .env file (from your local machine)
# scp .env root@YOUR_SERVER_IP:/opt/sure/

# Copy backup scripts
# scp backup.sh restore.sh root@YOUR_SERVER_IP:/opt/sure/

# Make scripts executable
chmod +x backup.sh restore.sh

# Create necessary directories
mkdir -p backups logs

# Start application
docker compose up -d

# Check status
docker compose ps
```

### 3. SSL Configuration (Let's Encrypt)

```bash
# Install Nginx and Certbot
apt install -y nginx certbot python3-certbot-nginx

# Create Nginx configuration
nano /etc/nginx/sites-available/sure
```

Add Nginx config:
```nginx
server {
    listen 80;
    server_name yourdomain.com www.yourdomain.com;

    location / {
        proxy_pass http://localhost:3010;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_set_header X-Forwarded-Host $host;
        proxy_set_header X-Forwarded-Port $server_port;
    }
}
```

```bash
# Enable site
ln -s /etc/nginx/sites-available/sure /etc/nginx/sites-enabled/
rm /etc/nginx/sites-enabled/default

# Test Nginx
nginx -t

# Start Nginx
systemctl enable nginx
systemctl start nginx

# Get SSL certificate
certbot --nginx -d yourdomain.com -d www.yourdomain.com
```

---

## Configure Backups

### 1. Automated Daily Backups

```bash
# Edit crontab
crontab -e
```

Add these lines:
```bash
# Daily backup at 2 AM
0 2 * * * /opt/sure/backup.sh >> /var/log/sure-backup.log 2>&1

# Weekly backup on Sunday at 3 AM (keep 30 days)
0 3 * * 0 /opt/sure/backup.sh --retention-days 30 >> /var/log/sure-weekly-backup.log 2>&1

# Monthly backup on 1st at 4 AM (keep 365 days)
0 4 1 * * /opt/sure/backup.sh --retention-days 365 >> /var/log/sure-monthly-backup.log 2>&1
```

### 2. Backup Monitoring

```bash
# Create health check script
nano /opt/sure/monitor-backups.sh
```

Add:
```bash
#!/bin/bash

# Check if backup ran today
TODAY=$(date +%Y%m%d)
BACKUP_FILE=$(ls -t /opt/sure/backups/db_backup_*.sql 2>/dev/null | head -n 1 | grep -o '[0-9]\{8\}')

if [ "$BACKUP_FILE" != "$TODAY" ]; then
    echo "[$(date)] WARNING: No backup found for today!" >> /var/log/sure-backup-monitor.log
    # Send email alert (configure mailutils first)
    # echo "Backup failed for Sure on $(hostname)" | mail -s "Backup Alert" your@email.com
fi

# Check disk space
DISK_USAGE=$(df /opt/sure/backups | awk 'NR==2 {print $5}' | sed 's/%//')
if [ "$DISK_USAGE" -gt 80 ]; then
    echo "[$(date)] WARNING: Backup disk usage at ${DISK_USAGE}%" >> /var/log/sure-backup-monitor.log
    # echo "Backup disk at ${DISK_USAGE}% on $(hostname)" | mail -s "Disk Space Alert" your@email.com
fi
```

```bash
# Make executable
chmod +x /opt/sure/monitor-backups.sh

# Add to crontab to run every hour
0 * * * * /opt/sure/monitor-backups.sh
```

### 3. Log Rotation

```bash
# Create logrotate configuration
nano /etc/logrotate.d/sure-backup
```

Add:
```
/var/log/sure-backup.log {
    daily
    rotate 14
    compress
    delaycompress
    missingok
    notifempty
    create 0640 root root
}

/var/log/sure-weekly-backup.log {
    weekly
    rotate 8
    compress
    delaycompress
    missingok
    notifempty
    create 0640 root root
}

/var/log/sure-monthly-backup.log {
    monthly
    rotate 12
    compress
    delaycompress
    missingok
    notifempty
    create 0640 root root
}
```

---

## Off-Site Backup Strategy

### Option 1: AWS S3 (Recommended)

```bash
# Install AWS CLI
apt install -y awscli

# Configure AWS credentials
aws configure
# Enter your AWS Access Key and Secret Key
# Default region: us-east-1
# Default output format: json

# Test connection
aws s3 ls

# Create S3 bucket (if not exists)
aws s3 mb s3://your-backup-bucket-name

# Enable versioning on bucket
aws s3api put-bucket-versioning \
    --bucket your-backup-bucket-name \
    --versioning-configuration Status=Enabled

# Create backup script with S3 sync
nano /opt/sure/backup-with-s3.sh
```

Add:
```bash
#!/bin/bash

# Run local backup
/opt/sure/backup.sh

# Sync to S3
aws s3 sync /opt/sure/backups/ s3://your-backup-bucket-name/sure-backups/ \
    --delete \
    --storage-class STANDARD_IA

# Log S3 sync result
echo "[$(date)] S3 sync completed" >> /var/log/sure-s3-backup.log
```

```bash
# Make executable
chmod +x /opt/sure/backup-with-s3.sh

# Update crontab to use S3 backup
crontab -e
# Replace daily backup with:
0 2 * * * /opt/sure/backup-with-s3.sh >> /var/log/sure-backup.log 2>&1
```

**S3 Costs:**
- Storage: ~$0.023/GB/month (STANDARD_IA)
- Example: 10GB = $0.23/month

### Option 2: Google Cloud Storage

```bash
# Install Google Cloud SDK
apt install -y apt-transport-https ca-certificates gnupg
curl https://packages.cloud.google.com/apt/doc/apt-key.gpg | apt-key add -
echo "deb https://packages.cloud.google.com/apt cloud-sdk main" | tee -a /etc/apt/sources.list.d/google-cloud-sdk.list
apt update && apt install -y google-cloud-sdk

# Authenticate
gcloud auth login

# Configure default project
gcloud config set project your-project-id

# Create bucket
gsutil mb gs://your-backup-bucket-name

# Create backup script with GCS sync
nano /opt/sure/backup-with-gcs.sh
```

Add:
```bash
#!/bin/bash

# Run local backup
/opt/sure/backup.sh

# Sync to GCS
gsutil rsync -r /opt/sure/backups/ gs://your-backup-bucket-name/sure-backups/

# Log GCS sync result
echo "[$(date)] GCS sync completed" >> /var/log/sure-gcs-backup.log
```

```bash
# Make executable
chmod +x /opt/sure/backup-with-gcs.sh

# Update crontab
crontab -e
# Replace daily backup with:
0 2 * * * /opt/sure/backup-with-gcs.sh >> /var/log/sure-backup.log 2>&1
```

**GCS Costs:**
- Storage: ~$0.020/GB/month
- Example: 10GB = $0.20/month

### Option 3: Backblaze B2

```bash
# Download and install B2 CLI
wget https://github.com/Backblaze/B2_Command_Line_Tool/releases/latest/download/backblaze-b2-linux
mv backblaze-b2-linux /usr/local/bin/b2
chmod +x /usr/local/bin/b2

# Authorize
b2 authorize-account
# Enter your Account ID and Application Key

# Create bucket
b2 create-bucket sure-backups your-unique-bucket-name

# Create backup script with B2 sync
nano /opt/sure/backup-with-b2.sh
```

Add:
```bash
#!/bin/bash

# Run local backup
/opt/sure/backup.sh

# Sync to B2
b2 sync /opt/sure/backups/ b2://sure-backups/

# Log B2 sync result
echo "[$(date)] B2 sync completed" >> /var/log/sure-b2-backup.log
```

```bash
# Make executable
chmod +x /opt/sure/backup-with-b2.sh

# Update crontab
crontab -e
# Replace daily backup with:
0 2 * * * /opt/sure/backup-with-b2.sh >> /var/log/sure-backup.log 2>&1
```

**B2 Costs:**
- Storage: $0.005/GB/month
- Example: 10GB = $0.05/month (cheapest option!)

---

## Monitoring and Alerts

### 1. Application Health Check

```bash
# Create health check script
nano /opt/sure/health-check.sh
```

Add:
```bash
#!/bin/bash

# Check if application is responding
if curl -f -s https://yourdomain.com > /dev/null; then
    echo "[$(date)] Application is healthy" >> /var/log/sure-health.log
else
    echo "[$(date)] ERROR: Application is down" >> /var/log/sure-health.log
    # Try to restart
    cd /opt/sure
    docker compose restart web worker
    # Send alert
    # echo "Sure application down on $(hostname)" | mail -s "App Down Alert" your@email.com
fi

# Check Docker containers
if ! docker compose ps | grep -q "Up"; then
    echo "[$(date)] ERROR: Docker containers not running" >> /var/log/sure-health.log
    cd /opt/sure
    docker compose up -d
fi
```

```bash
# Make executable
chmod +x /opt/sure/health-check.sh

# Add to crontab (every 5 minutes)
crontab -e
*/5 * * * * /opt/sure/health-check.sh
```

### 2. Disk Space Monitoring

```bash
# Create disk space check
nano /opt/sure/check-disk-space.sh
```

Add:
```bash
#!/bin/bash

# Check root partition
ROOT_USAGE=$(df / | awk 'NR==2 {print $5}' | sed 's/%//')
if [ "$ROOT_USAGE" -gt 85 ]; then
    echo "[$(date)] WARNING: Root disk at ${ROOT_USAGE}%" >> /var/log/sure-disk-alert.log
    # echo "Root disk at ${ROOT_USAGE}% on $(hostname)" | mail -s "Disk Space Alert" your@email.com

    # Try to clean up
    docker system prune -f
    docker volume prune -f
fi

# Check backup partition
BACKUP_USAGE=$(df /opt/sure/backups | awk 'NR==2 {print $5}' | sed 's/%//')
if [ "$BACKUP_USAGE" -gt 80 ]; then
    echo "[$(date)] WARNING: Backup disk at ${BACKUP_USAGE}%" >> /var/log/sure-disk-alert.log
    # Clean old backups
    find /opt/sure/backups -name "*.sql" -mtime +7 -delete
    find /opt/sure/backups -name "*.tar.gz" -mtime +7 -delete
fi
```

```bash
# Make executable
chmod +x /opt/sure/check-disk-space.sh

# Add to crontab (daily)
crontab -e
0 6 * * * /opt/sure/check-disk-space.sh
```

### 3. Email Alerts Setup

```bash
# Install mailutils
apt install -y mailutils

# Configure email (Postfix)
dpkg-reconfigure postfix

# Choose: "Internet Site"
# System mail name: yourdomain.com

# Test email
echo "Test email from $(hostname)" | mail -s "Test" your@email.com
```

---

## Disaster Recovery

### Scenario 1: Corrupted Database

```bash
# Stop application
cd /opt/sure
docker compose stop web worker

# Check available backups
./restore.sh --list

# Restore latest database backup
./restore.sh --db backups/db_backup_YYYYMMDD_HHMMSS.sql --force

# Verify restoration
docker compose logs -f db
docker compose exec db psql -U sure_user sure_production -c "SELECT COUNT(*) FROM users;"

# Start application
docker compose start web worker
```

### Scenario 2: Full Server Failure

1. **Provision new VPS** (same or different provider)
2. **Repeat initial setup** (see [Initial Setup](#initial-setup))
3. **Copy configuration files** from backup
4. **Restore from off-site backup**

```bash
# Download backups from S3
aws s3 sync s3://your-backup-bucket-name/sure-backups/ /opt/sure/backups/

# Restore database
/opt/sure/restore.sh --db /opt/sure/backups/db_backup_YYYYMMDD_HHMMSS.sql --force

# Restore storage
/opt/sure/restore.sh --storage /opt/sure/backups/storage_backup_YYYYMMDD_HHMMSS.tar.gz --force

# Start application
cd /opt/sure
docker compose up -d
```

### Scenario 3: Accidental Data Deletion

```bash
# Check pre-restore backups (created automatically during restore)
ls -lh backups/pre_restore/

# Restore from pre-restore backup
/opt/sure/restore.sh --db backups/pre_restore/db_pre_restore_YYYYMMDD_HHMMSS.sql --force
```

### Scenario 4: Ransomware Attack

1. **Immediately shut down server**
2. **Assess damage** from backups (don't restore to compromised server)
3. **Provision clean VPS**
4. **Restore from off-site backup** (verify integrity first)
5. **Change all passwords** and API keys
6. **Review security** and harden system
7. **Update all dependencies**

---

## Maintenance

### Daily Tasks

```bash
# Check backup logs
tail -20 /var/log/sure-backup.log

# Check application health
curl -I https://yourdomain.com

# Check disk space
df -h

# Check Docker containers
docker compose ps
```

### Weekly Tasks

```bash
# Review all logs
tail -100 /var/log/sure-backup.log
tail -100 /var/log/sure-health.log
tail -100 /var/log/sure-disk-alert.log

# Check backup sizes
du -sh /opt/sure/backups/

# Verify off-site sync
aws s3 ls s3://your-backup-bucket-name/sure-backups/
```

### Monthly Tasks

```bash
# Test backup restoration
/opt/sure/restore.sh --db backups/db_backup_$(date +%Y%m%d)_020000.sql --force

# Update system
apt update && apt upgrade -y

# Update Docker images
cd /opt/sure
docker compose pull
docker compose up -d

# Review and clean old backups
find /opt/sure/backups -name "*.sql" -mtime +30 -delete
find /opt/sure/backups -name "*.tar.gz" -mtime +30 -delete
```

### Quarterly Tasks

```bash
# Review and rotate off-site backups
# Consider archiving old backups to Glacier or similar

# Review backup strategy
# Adjust retention periods based on growth

# Test full disaster recovery
# Document any changes or improvements

# Security audit
# Review logs for suspicious activity
```

---

## Quick Reference

### Backup Commands

```bash
# Manual backup
/opt/sure/backup.sh

# Check backup status
tail -f /var/log/sure-backup.log

# List backups
/opt/sure/restore.sh --list

# Off-site sync
aws s3 sync /opt/sure/backups/ s3://your-bucket/sure-backups/
```

### Restore Commands

```bash
# Restore database
/opt/sure/restore.sh --db backups/db_backup_YYYYMMDD.sql --force

# Restore storage
/opt/sure/restore.sh --storage backups/storage_backup_YYYYMMDD.tar.gz --force

# Restore both
/opt/sure/restore.sh --all db.sql storage.tar.gz --force
```

### Docker Commands

```bash
# Check status
cd /opt/sure && docker compose ps

# View logs
docker compose logs -f

# Restart services
docker compose restart

# Update application
docker compose pull && docker compose up -d
```

### System Commands

```bash
# Check disk space
df -h

# Check resources
htop

# View logs
journalctl -u docker -f

# Check firewall
ufw status
```

---

## Support

For issues or questions:

1. Check main documentation: [BACKUP_RESTORE.md](BACKUP_RESTORE.md)
2. Review logs: `/var/log/sure-*.log`
3. Check GitHub: [we-promise/sure discussions](https://github.com/we-promise/sure/discussions)
4. VPS provider support (Hetzner, DigitalOcean, Linode)

---

## Important Notes

🔒 **Security First**
- Use strong passwords
- Enable SSH key authentication
- Regularly update system
- Monitor logs for suspicious activity

💾 **3-2-1 Backup Rule**
- 3 copies (production, local, off-site)
- 2 storage types (disk, cloud)
- 1 off-site backup

📊 **Regular Testing**
- Test restores monthly
- Verify off-site syncs
- Monitor backup logs

🔄 **Automate Everything**
- Daily automated backups
- Hourly health checks
- Weekly disk space monitoring

📝 **Document Everything**
- Keep runbooks updated
- Document restore procedures
- Track all changes
