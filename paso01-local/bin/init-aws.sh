#!/usr/bin/env bash
# ==================================================================
# PASO 01 (Paso 3) - Crea TODA la infraestructura dentro de
# LocalStack (SQS + DLQ, DynamoDB, SNS, las dos Lambdas Java, el
# event source mapping y la API Gateway). Es IDEMPOTENTE.
#
# Uso (desde la carpeta paso01-local):
#   ./bin/init-aws.sh tucorreo@duocuc.cl
#
# La lógica corre DENTRO del contenedor (scripts/init-aws.sh con
# awslocal); este wrapper solo copia los archivos y lo ejecuta.
# ==================================================================
set -e
cd "$(dirname "$0")/.."

EMAIL="${1:-alumno@duocuc.cl}"

if [ ! -f out/lambdas.zip ]; then
  echo "X Falta out/lambdas.zip. Compila primero:  ./bin/build.sh"
  exit 1
fi

if ! docker ps --filter "name=^localstack$" --filter "status=running" | grep -q localstack; then
  echo "X LocalStack no está corriendo. Levántalo con:  docker compose up -d"
  exit 1
fi

docker cp out/lambdas.zip localstack:/tmp/lambdas.zip >/dev/null
docker cp scripts/. localstack:/tmp/ >/dev/null
docker exec -e EMAIL_NOTIFICATIONS="$EMAIL" localstack bash /tmp/init-aws.sh
