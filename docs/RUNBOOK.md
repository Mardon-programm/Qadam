# Qadam Production Runbook

## Quick Reference

### Service URLs
- **API**: http://localhost/api/v1
- **Health Check**: http://localhost/health
- **API Docs** (dev only): http://localhost/docs
- **Grafana**: http://localhost:3000
- **Prometheus**: http://localhost:9090

### Common Commands

```bash
# Start all services
docker compose -f docker-compose.prod.yml up -d

# Stop all services
docker compose -f docker-compose.prod.yml down

# View logs
docker compose -f docker-compose.prod.yml logs -f [service]

# Restart a service
docker compose -f docker-compose.prod.yml restart [service]

# Health check
./infra/health-check.sh

# Database backup
./infra/backup-db.sh

# Deploy update
./infra/deploy.sh production
```

## Incident Response

### 1. API is Down (HTTP 502/503)

**Symptoms**: Health check returns 502/503, API not responding

**Diagnosis**:
```bash
# Check API container
docker compose -f docker-compose.prod.yml ps api
docker compose -f docker-compose.prod.yml logs --tail=100 api

# Check database connection
docker compose -f docker-compose.prod.yml exec postgres pg_isready
```

**Resolution**:
```bash
# Restart API
docker compose -f docker-compose.prod.yml restart api

# If still failing, check database
docker compose -f docker-compose.prod.yml restart postgres
sleep 10
docker compose -f docker-compose.prod.yml restart api
```

### 2. High Error Rate (5xx errors)

**Symptoms**: Grafana shows elevated error rate, alert fired

**Diagnosis**:
```bash
# Check recent errors
docker compose -f docker-compose.prod.yml logs --since 15m api | grep ERROR

# Check database connections
docker compose -f docker-compose.prod.yml exec postgres psql -U qadam -c \
  "SELECT count(*) as connections FROM pg_stat_activity;"
```

**Resolution**:
```bash
# If database connection limit reached
docker compose -f docker-compose.prod.yml exec postgres psql -U qadam -c \
  "SELECT pg_terminate_backend(pid) FROM pg_stat_activity 
   WHERE state = 'idle' AND state_change < now() - interval '10 minutes';"

# Restart API
docker compose -f docker-compose.prod.yml restart api
```

### 3. Database Performance Issues

**Symptoms**: Slow queries, timeouts

**Diagnosis**:
```bash
# Check active queries
docker compose -f docker-compose.prod.yml exec postgres psql -U qadam -c \
  "SELECT pid, now() - query_start as duration, query 
   FROM pg_stat_activity 
   WHERE state = 'active' 
   ORDER BY duration DESC;"

# Check database size
docker compose -f docker-compose.prod.yml exec postgres psql -U qadam -c \
  "SELECT pg_size_pretty(pg_database_size('qadam'));"
```

**Resolution**:
```bash
# Kill long-running query (if needed)
docker compose -f docker-compose.prod.yml exec postgres psql -U qadam -c \
  "SELECT pg_cancel_backend([pid]);"

# Run VACUUM
docker compose -f docker-compose.prod.yml exec postgres psql -U qadam -c \
  "VACUUM ANALYZE;"

# If critical, restart database
docker compose -f docker-compose.prod.yml restart postgres
```

### 4. Redis Memory Full

**Symptoms**: Redis evicting keys, cache misses

**Diagnosis**:
```bash
# Check Redis memory
docker compose -f docker-compose.prod.yml exec redis redis-cli \
  -a "$REDIS_PASSWORD" INFO memory
```

**Resolution**:
```bash
# Flush non-critical caches
docker compose -f docker-compose.prod.yml exec redis redis-cli \
  -a "$REDIS_PASSWORD" FLUSHDB

# Or increase Redis max memory in docker-compose.prod.yml
# Then restart
docker compose -f docker-compose.prod.yml restart redis
```

### 5. Disk Space Full

**Symptoms**: Services failing, cannot write logs

**Diagnosis**:
```bash
# Check disk usage
df -h

# Find large files
du -sh /var/lib/docker/* | sort -h
du -sh ~/qadam/backups/* | sort -h
```

**Resolution**:
```bash
# Clean old Docker resources
docker system prune -a --volumes

# Remove old backups (keep last 7 days)
find ~/qadam/backups -name "*.sql.gz" -mtime +7 -delete

# Clean old logs
docker compose -f docker-compose.prod.yml exec nginx \
  sh -c "truncate -s 0 /var/log/nginx/*.log"
```

### 6. Payment Provider Down

**Symptoms**: All payments failing, webhook timeouts

**Diagnosis**:
```bash
# Check recent payment logs
docker compose -f docker-compose.prod.yml logs api | grep payment

# Check webhook endpoint
curl -X POST https://webhook.provider.com/test
```

**Resolution**:
```bash
# Enable maintenance mode (optional)
# Show user-friendly error in payment flow

# Monitor provider status page
# Wait for provider to recover

# Retry failed payments (implement retry mechanism in worker)
docker compose -f docker-compose.prod.yml restart worker
```

### 7. No Drivers Online

**Symptoms**: Alert fired, no drivers accepting rides

**Diagnosis**:
```bash
# Check driver app connectivity
# Review recent driver session logs
docker compose -f docker-compose.prod.yml logs api | grep driver_session

# Check if dispatch service is working
docker compose -f docker-compose.prod.yml logs api | grep dispatch
```

**Resolution**:
- Verify driver apps are working
- Check for network issues
- Review driver complaints
- Send notifications to offline drivers

## Monitoring

### Key Metrics to Watch

1. **API Response Time** (target: p95 < 500ms)
2. **Error Rate** (target: < 1%)
3. **Active Rides** (monitor trends)
4. **Drivers Online** (alert if 0)
5. **Payment Success Rate** (target: > 95%)
6. **Database Connections** (alert at 80% capacity)
7. **Disk Space** (alert at 80%)

### Alert Priorities

**Critical** (immediate action):
- API down
- Database down
- No drivers online
- Disk space > 90%

**Warning** (action within 1 hour):
- High error rate
- High latency
- Database connections high
- Memory usage high

**Info** (monitor):
- No rides created (30 min)
- Payment failure rate elevated

## Maintenance Windows

### Weekly Maintenance (Sunday 2-4 AM)

```bash
# 1. Backup database
./infra/backup-db.sh

# 2. Run VACUUM on database
docker compose -f docker-compose.prod.yml exec postgres \
  psql -U qadam -c "VACUUM ANALYZE;"

# 3. Check for updates
git fetch origin main

# 4. Clean Docker resources
docker system prune -f

# 5. Review logs for errors
docker compose -f docker-compose.prod.yml logs --since 7d api | \
  grep ERROR > /tmp/weekly-errors.log

# 6. Update Grafana dashboards if needed
```

### Monthly Maintenance (First Sunday 2-6 AM)

```bash
# 1. Full system backup
./infra/backup-db.sh

# 2. Update dependencies (if available)
# Review release notes first

# 3. Database maintenance
docker compose -f docker-compose.prod.yml exec postgres \
  psql -U qadam -c "REINDEX DATABASE qadam;"

# 4. Review and rotate logs

# 5. Security updates
sudo apt update && sudo apt upgrade -y

# 6. Certificate renewal (if expiring)
sudo certbot renew
```

## Escalation

### Level 1: On-call Engineer
- Service restarts
- Standard troubleshooting
- Log investigation

### Level 2: Senior Engineer
- Database issues
- Performance optimization
- Configuration changes

### Level 3: Platform Lead
- Architecture decisions
- Major incidents
- Vendor coordination

## Contact Information

- **On-call**: [phone/email]
- **DevOps Team**: ops@qadam.kg
- **Platform Lead**: [email]
- **Emergency**: [phone]

## External Dependencies

- **SMS Provider**: [status page URL]
- **Payment Provider**: [status page URL]
- **Cloud Provider**: [status page URL]
- **DNS Provider**: [status page URL]
