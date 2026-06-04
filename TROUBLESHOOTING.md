# Docker Compose Setup & Troubleshooting Guide

## Getting Started

### 1. Start Services
```bash
docker compose up -d
sleep 60  # Wait for services to initialize
docker compose ps
```

### 2. Get Jenkins Initial Admin Password
```bash
docker compose exec -T jenkins cat /var/jenkins_home/secrets/initialAdminPassword
```

Save this password - you'll need it for first-time Jenkins login.

### 3. Access Services

| Service | URL | Username | Password |
|---------|-----|----------|----------|
| Jenkins | http://localhost:8080/jenkins | admin | (from step 2) |
| SonarQube | http://localhost:9000 | admin | admin |
| PostgreSQL | localhost:5432 | postgres | postgres |

### 4. Verify Services are Healthy
```bash
docker compose ps
```

All three services should show `Up X seconds (healthy)` or `Up X seconds (health: starting)` for SonarQube in first 2 minutes.

---

## Troubleshooting

### SonarQube Database Connection Failed
**Error:** `FATAL: database "sonarqube" does not exist`

**Cause:** PostgreSQL init script didn't run or credentials mismatch

**Fix:**
```bash
# Verify credentials in docker-compose.yml match init-db.sh
# Both should use: postgres/postgres

# Reset and restart
docker compose down -v
docker compose up -d
sleep 60
```

### SonarQube Elasticsearch Permission Denied
**Error:** `java.nio.file.AccessDeniedException: /opt/sonarqube/logs`

**Cause:** Corrupt volumes from previous failed startup

**Fix:**
```bash
docker compose down -v
docker compose up -d
sleep 60  # Wait for Elasticsearch to initialize
```

### Services Won't Start
**Fix: Complete Reset**
```bash
docker compose down -v
docker volume prune -f
docker compose build --no-cache
docker compose up -d
sleep 60
docker compose ps
```

### View Service Logs
```bash
# All services
docker compose logs

# Specific service
docker compose logs sonarqube
docker compose logs postgres-db
docker compose logs jenkins

# Last 50 lines
docker compose logs sonarqube | tail -50
```

---

## Verify Setup

### Check Databases Created
```bash
docker compose exec -T postgres-db psql -U postgres -c "SELECT datname FROM pg_database WHERE datname IN ('sonarqube', 'bugreportportal');"
```

**Expected output:**
```
  datname
-----------------
 sonarqube
 bugreportportal
```

### Check SonarQube Health
```bash
curl -s http://localhost:9000/api/system/health | jq .
```

**Expected output (when healthy):**
```json
{
  "health": "UP",
  "status": "UP",
  "causes": []
}
```

### Check Jenkins Health
```bash
curl -I http://localhost:8080/jenkins/login
```

**Expected output:** `HTTP/1.1 200 OK`

---

## Stop Services

```bash
# Stop containers (keep volumes)
docker compose stop

# Stop and remove containers (keep volumes)
docker compose down

# Stop and remove everything (fresh start next time)
docker compose down -v
```

---

## Common Commands

```bash
# View all containers
docker compose ps -a

# View specific service logs
docker compose logs -f sonarqube

# Execute command in container
docker compose exec -T jenkins command-here

# Rebuild Jenkins image
docker compose build --no-cache jenkins
```
