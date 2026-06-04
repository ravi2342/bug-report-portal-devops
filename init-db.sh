#!/bin/bash
set -e

psql --username "$POSTGRES_USER" <<-EOSQL
  CREATE DATABASE sonarqube OWNER $POSTGRES_USER;
  CREATE DATABASE bugreportportal OWNER $POSTGRES_USER;
EOSQL
