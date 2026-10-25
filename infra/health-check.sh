# Health Check Script for Qadam Services
# Usage: ./health-check.sh

set -e

echo "🏥 Qadam Health Check - $(date)"
echo "================================"

# Color codes
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

check_service() {
    local service=$1
    local url=$2

    if curl -sf "$url" > /dev/null; then
        echo -e "${GREEN}✓${NC} $service: OK"
        return 0
    else
        echo -e "${RED}✗${NC} $service: FAILED"
        return 1
    fi
}

check_docker() {
    local container=$1

    if docker ps --filter "name=$container" --filter "status=running" | grep -q "$container"; then
        echo -e "${GREEN}✓${NC} Container $container: Running"
        return 0
    else
        echo -e "${RED}✗${NC} Container $container: Not running"
        return 1
    fi
}

# Check Docker containers
echo ""
echo "📦 Docker Containers:"
check_docker "qadam-api-prod"
check_docker "qadam-postgres-prod"
check_docker "qadam-redis-prod"
check_docker "qadam-nginx-prod"
check_docker "qadam-worker-prod"

# Check services
echo ""
echo "🌐 Services Health:"
check_service "API" "http://localhost/health"
check_service "Prometheus" "http://localhost:9090/-/healthy"
check_service "Grafana" "http://localhost:3000/api/health"

# Check database
echo ""
echo "🗄️  Database:"
DB_STATUS=$(docker compose -f docker-compose.prod.yml exec -T postgres pg_isready -U qadam 2>&1 || echo "failed")
if echo "$DB_STATUS" | grep -q "accepting connections"; then
    echo -e "${GREEN}✓${NC} PostgreSQL: Accepting connections"
else
    echo -e "${RED}✗${NC} PostgreSQL: Not ready"
fi

# Check Redis
echo ""
echo "💾 Redis:"
REDIS_STATUS=$(docker compose -f docker-compose.prod.yml exec -T redis redis-cli -a "$REDIS_PASSWORD" ping 2>&1 || echo "failed")
if echo "$REDIS_STATUS" | grep -q "PONG"; then
    echo -e "${GREEN}✓${NC} Redis: Connected"
else
    echo -e "${RED}✗${NC} Redis: Not responding"
fi

# Check disk space
echo ""
echo "💿 Disk Space:"
DISK_USAGE=$(df -h / | awk 'NR==2 {print $5}' | sed 's/%//')
if [ "$DISK_USAGE" -lt 80 ]; then
    echo -e "${GREEN}✓${NC} Disk usage: ${DISK_USAGE}%"
elif [ "$DISK_USAGE" -lt 90 ]; then
    echo -e "${YELLOW}⚠${NC} Disk usage: ${DISK_USAGE}% (Warning)"
else
    echo -e "${RED}✗${NC} Disk usage: ${DISK_USAGE}% (Critical)"
fi

# Check memory
echo ""
echo "🧠 Memory:"
MEM_USAGE=$(free | grep Mem | awk '{printf "%.0f", ($3/$2) * 100}')
if [ "$MEM_USAGE" -lt 80 ]; then
    echo -e "${GREEN}✓${NC} Memory usage: ${MEM_USAGE}%"
elif [ "$MEM_USAGE" -lt 90 ]; then
    echo -e "${YELLOW}⚠${NC} Memory usage: ${MEM_USAGE}% (Warning)"
else
    echo -e "${RED}✗${NC} Memory usage: ${MEM_USAGE}% (Critical)"
fi

# Check recent logs for errors
echo ""
echo "📝 Recent Errors (last 10 minutes):"
ERROR_COUNT=$(docker compose -f docker-compose.prod.yml logs --since 10m api 2>&1 | grep -i error | wc -l)
if [ "$ERROR_COUNT" -eq 0 ]; then
    echo -e "${GREEN}✓${NC} No errors found"
else
    echo -e "${YELLOW}⚠${NC} Found $ERROR_COUNT error entries"
fi

echo ""
echo "================================"
echo "Health check completed"
