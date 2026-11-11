#!/usr/bin/env bash
# ==================================================================
# PASO 01 (Paso 5) - Estado del sistema: tabla DynamoDB, colas SQS
# (pendientes y DLQ) y suscripciones SNS.
#
# Uso (desde la carpeta paso01-local):  ./bin/estado.sh
#
# La lógica corre DENTRO del contenedor (scripts/estado.sh con awslocal).
# ==================================================================
set -e
cd "$(dirname "$0")/.."

if ! docker ps --filter "name=^localstack$" --filter "status=running" | grep -q localstack; then
  echo "X LocalStack no está corriendo. Levántalo con:  docker compose up -d"
  exit 1
fi

docker cp scripts/. localstack:/tmp/ >/dev/null
docker exec localstack bash /tmp/estado.sh
