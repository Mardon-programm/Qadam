# Qadam Production Deployment Guide

## Prerequisites

- Docker 24.0+
- Docker Compose 2.20+
- Linux server (Ubuntu 22.04 LTS recommended)
- Minimum 4GB RAM, 2 CPU cores, 50GB disk
- Domain name with DNS configured (for SSL)

## Initial Setup

### 1. Server Preparation

```bash
# Update system
sudo apt update && sudo apt upgrade -y

# Install Docker
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh

# Install Docker Compose
sudo apt install docker-compose-plugin -y

# Create qadam user
sudo useradd -m -s /bin/bash qadam
sudo usermod -aG docker qadam
```

### 2. Clone Repository

```bash
sudo su - qadam
git clone https://github.com/your-org/qadam.git
cd qadam
```

### 3. Configure Environment

```bash
# Copy environment template
cp .env.example .env

# Edit configuration
nano .env
```

Required environment variables:

```env
# App
APP_ENV=production
SECRET_KEY=<generate-strong-random-key>

# Database
POSTGRES_DB=qadam
POSTGRES_USER=qadam
POSTGRES_PASSWORD=<strong-password>

# Redis
REDIS_PASSWORD=<strong-password>

# JWT
JWT_SECRET_KEY=<generate-strong-random-key>
JWT_ALGORITHM=HS256
ACCESS_TOKEN_EXPIRE_MINUTES=60
REFRESH_TOKEN_EXPIRE_DAYS=30

# SMS Provider (configure your provider)
SMS_PROVIDER=<provider-name>
SMS_API_KEY=<your-api-key>

# Payment Provider
PAYMENT_PROVIDER=<provider-name>
PAYMENT_API_KEY=<your-api-key>
PAYMENT_WEBHOOK_SECRET=<webhook-secret>

# Monitoring
GRAFANA_PASSWORD=<strong-password>
```

### 4. SSL/TLS Setup

For production, use Let's Encrypt:

```bash
# Install certbot
sudo apt install certbot -y

# Generate certificates
sudo certbot certonly --standalone -d api.qadam.kg -d ops.qadam.kg

# Copy certificates
sudo cp /etc/letsencrypt/live/api.qadam.kg/fullchain.pem infra/nginx/ssl/
sudo cp /etc/letsencrypt/live/api.qadam.kg/privkey.pem infra/nginx/ssl/
sudo chown -R qadam:qadam infra/nginx/ssl/
```

Update nginx.conf to enable HTTPS:

```nginx
server {
    listen 443 ssl http2;
    server_name api.qadam.kg;
    
    ssl_certificate /etc/nginx/ssl/fullchain.pem;
    ssl_certificate_key /etc/nginx/ssl/privkey.pem;
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers HIGH:!aNULL:!MD5;
    
    # ... rest of config
}
```

### 5. Database Initialization

```bash
# Create backup directory
mkdir -p backups

# Start database only
docker compose -f docker-compose.prod.yml up -d postgres redis

# Wait for database to be ready
sleep 10

# Run migrations
docker compose -f docker-compose.prod.yml run --rm api alembic upgrade head
```

### 6. Deploy Application

```bash
# Deploy all services
./infra/deploy.sh production
```

## Service Management

### Start services
```bash
docker compose -f docker-compose.prod.yml up -d
```

### Stop services
```bash
docker compose -f docker-compose.prod.yml down
```

### View logs
```bash
docker compose -f docker-compose.prod.yml logs -f api
docker compose -f docker-compose.prod.yml logs -f worker
```

### Scale API instances
```bash
docker compose -f docker-compose.prod.yml up -d --scale api=3
```

## Monitoring

### Access Grafana
- URL: http://your-server:3000
- Default login: admin / <GRAFANA_PASSWORD from .env>
- Import dashboard from `infra/monitoring/grafana-dashboards/`

### Access Prometheus
- URL: http://your-server:9090
- Metrics endpoint: http://your-server/metrics

## Backup & Restore

### Setup automated backups

```bash
# Add to crontab
crontab -e

# Daily backup at 2 AM
0 2 * * * /home/qadam/qadam/infra/backup-db.sh >> /var/log/qadam-backup.log 2>&1
```

### Manual backup

```bash
./infra/backup-db.sh
```

### Restore from backup

```bash
# Stop services
docker compose -f docker-compose.prod.yml down

# Restore database
gunzip -c backups/qadam_YYYYMMDD_HHMMSS.sql.gz | \
docker compose -f docker-compose.prod.yml exec -T postgres psql -U qadam -d qadam

# Start services
docker compose -f docker-compose.prod.yml up -d
```

## Security Checklist

- [ ] Change all default passwords in .env
- [ ] Enable SSL/TLS with valid certificates
- [ ] Configure firewall (UFW):
  ```bash
  sudo ufw allow 22/tcp   # SSH
  sudo ufw allow 80/tcp   # HTTP
  sudo ufw allow 443/tcp  # HTTPS
  sudo ufw enable
  ```
- [ ] Disable API docs in production (remove /docs endpoint)
- [ ] Enable rate limiting in nginx
- [ ] Configure fail2ban for SSH
- [ ] Set up log rotation
- [ ] Enable audit logging
- [ ] Configure backup encryption
- [ ] Implement secrets management (e.g., Vault)

## Performance Tuning

### PostgreSQL

Edit `postgresql.conf`:

```conf
shared_buffers = 1GB
effective_cache_size = 3GB
maintenance_work_mem = 256MB
checkpoint_completion_target = 0.9
wal_buffers = 16MB
default_statistics_target = 100
random_page_cost = 1.1
effective_io_concurrency = 200
work_mem = 10MB
min_wal_size = 1GB
max_wal_size = 4GB
```

### Redis

```conf
maxmemory 512mb
maxmemory-policy allkeys-lru
```

## Troubleshooting

### API not responding
```bash
# Check API health
curl http://localhost/health

# Check container status
docker compose -f docker-compose.prod.yml ps

# Check logs
docker compose -f docker-compose.prod.yml logs api
```

### Database connection issues
```bash
# Check database status
docker compose -f docker-compose.prod.yml exec postgres pg_isready

# Check connections
docker compose -f docker-compose.prod.yml exec postgres psql -U qadam -c "SELECT count(*) FROM pg_stat_activity;"
```

### High memory usage
```bash
# Check container stats
docker stats

# Restart services if needed
docker compose -f docker-compose.prod.yml restart
```

## Maintenance

### Update application
```bash
git pull origin main
./infra/deploy.sh production
```

### Clean up Docker resources
```bash
docker system prune -a --volumes
```

### Review logs
```bash
# Application logs
docker compose -f docker-compose.prod.yml logs --tail=100 api

# Nginx logs
docker compose -f docker-compose.prod.yml exec nginx tail -f /var/log/nginx/access.log
```

## Support

For issues and questions:
- Documentation: `/docs/docs.md`
- GitHub Issues: https://github.com/your-org/qadam/issues
- Email: ops@qadam.kg
