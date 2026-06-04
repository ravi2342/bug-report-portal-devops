#!/bin/bash
set -e

# Create SonarQube database only
# (Bug Report Portal app uses its own PostgreSQL in K8s)
psql --username "$POSTGRES_USER" <<-EOSQL
  CREATE DATABASE sonarqube OWNER $POSTGRES_USER;
EOSQL
