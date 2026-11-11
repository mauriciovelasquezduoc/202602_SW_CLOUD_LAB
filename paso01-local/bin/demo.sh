#!/usr/bin/env bash
# ==================================================================
# PASO 01 (Paso 4) - Prueba de punta a punta.
# Envía un POST /solicitudes válido, muestra la respuesta 202 con
# estado RECIBIDA, y queda mirando DynamoDB hasta que la Lambda de
# procesamiento deja el ítem con estado PROCESADA.
#
# Uso (desde la carpeta paso01-local):  ./bin/demo.sh
#
# La lógica corre DENTRO del contenedor (scripts/demo.sh con awslocal).
# ==================================================================
set -e
cd "$(dirname "$0")/.."

if ! docker ps --filter "name=^localstack$" --filter "status=running" | grep -q localstack; then
  echo "X LocalStack no está corriendo. Levántalo con:  docker compose up -d"
  exit 1
fi

docker cp scripts/. localstack:/tmp/ >/dev/null
docker exec localstack bash /tmp/demo.sh
