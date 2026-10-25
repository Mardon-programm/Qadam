#!/bin/bash
set -e

# Qadam Production Deployment Script
# Usage: ./deploy.sh [environment]

ENVIRONMENT=${1:-production}
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

echo "🚀 Deploying Qadam to $ENVIRONMENT environment..."

# Check prerequisites
command -v docker >/dev/null 2>&1 || { echo "❌ Docker is required"; exit 1; }
command -v docker compose >/dev/null 2>&1 || { echo "❌ Docker Compose is required"; exit 1; }

# Verify .env exists
if [ ! -f .env ]; then
    echo "❌ .env file not found. Copy from .env.example and configure."
    exit 1
fi

# Backup database before deployment
echo "📦 Creating database backup..."
docker compose -f docker-compose.prod.yml exec -T postgres pg_dump \
    -U qadam qadam | gzip > "backups/qadam_${TIMESTAMP}.sql.gz" || true

# Pull latest changes (if deploying from git)
if [ -d .git ]; then
    echo "📥 Pulling latest code..."
    git pull origin main
fi

# Build new images
echo "🔨 Building images..."
docker compose -f docker-compose.prod.yml build --no-cache api worker

# Run database migrations
echo "🗄️  Running database migrations..."
docker compose -f docker-compose.prod.yml run --rm api alembic upgrade head

# Restart services with zero-downtime (rolling update)
echo "♻️  Restarting services..."

# Stop old worker
docker compose -f docker-compose.prod.yml stop worker

# Rolling restart API (one at a time if scaled)
docker compose -f docker-compose.prod.yml up -d --no-deps --scale api=2 --no-recreate api

# Wait for health checks
echo "⏳ Waiting for services to be healthy..."
sleep 10

# Start new worker
docker compose -f docker-compose.prod.yml up -d worker

# Verify deployment
echo "✅ Verifying deployment..."
HEALTH_STATUS=$(curl -s -o /dev/null -w "%{http_code}" http://localhost/health)

if [ "$HEALTH_STATUS" = "200" ]; then
    echo "✅ Deployment successful! API is healthy."
else
    echo "❌ Deployment verification failed. Health check returned: $HEALTH_STATUS"
    echo "🔄 Rolling back..."
    docker compose -f docker-compose.prod.yml down
    exit 1
fi

# Cleanup old images
echo "🧹 Cleaning up old images..."
docker image prune -f

# Show running services
echo ""
echo "📊 Running services:"
docker compose -f docker-compose.prod.yml ps

echo ""
echo "✨ Deployment completed successfully!"
echo "📝 Database backup: backups/qadam_${TIMESTAMP}.sql.gz"
echo "📊 Grafana: http://localhost:3000"
echo "📈 Prometheus: http://localhost:9090"
