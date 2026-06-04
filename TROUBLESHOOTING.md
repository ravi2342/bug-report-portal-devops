# Docker Compose Troubleshooting Guide

## Quick Start Issues

### SonarQube Database Connection Failed
**Error:** `FATAL: database "sonarqube" does not exist`

**Fix:** Use PostgreSQL default credentials (`postgres/postgres`) in:
- `docker-compose.yml` (SONAR_JDBC_USERNAME, SONAR_JDBC_PASSWORD)
- `init-db.sh` script for database creation
- PostgreSQL healthcheck

### SonarQube Elasticsearch Permission Denied
**Error:** `java.nio.file.AccessDeniedException: /opt/sonarqube/logs`

**Fix:** Remove corrupt volumes and restart fresh:
```bash
docker compose down -v
docker compose up -d
sleep 60  # Wait for SonarQube Elasticsearch to initialize
```

### SonarQube Takes Too Long to Start
SonarQube's embedded Elasticsearch needs 2-3 minutes for first startup. The healthcheck is configured with `start_period: 120s` to account for this.

## Complete Reset

If services fail to start properly:
```bash
docker compose down -v
docker volume prune -f
docker compose build --no-cache
docker compose up -d
sleep 60
docker compose ps
```

## Verify Services

```bash
# Check all services are running
docker compose ps

# Test PostgreSQL databases exist
docker compose exec -T postgres-db psql -U postgres -c "SELECT datname FROM pg_database;"

# Test SonarQube health
curl -s http://localhost:9000/api/system/health | jq .

# View logs
docker compose logs sonarqube
```

## Service URLs & Credentials

| Service | URL | Credentials |
|---------|-----|-------------|
| Jenkins | http://localhost:8080/jenkins | admin / (see init password) |
| SonarQube | http://localhost:9000 | admin/admin |
| PostgreSQL | localhost:5432 | postgres/postgres |
