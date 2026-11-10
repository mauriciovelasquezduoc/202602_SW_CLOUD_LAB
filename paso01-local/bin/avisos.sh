#!/usr/bin/env bash
# ==================================================================
# PASO 01 (Paso 5) - Lee la "bandeja" simulada de notificaciones SNS.
# En local no hay SMTP: las notificaciones quedan en una cola SQS
# suscrita al tópico. En el paso 02 (nube real) llegan por EMAIL.
#
# Uso (desde la carpeta paso01-local):  ./bin/avisos.sh
#
# Nota: SQS hace invisible cada mensaje ~30 s tras leerlo; si acabas
# de leer la bandeja, espera 30 s y reintenta.
# ==================================================================
set -e
cd "$(dirname "$0")/.."

if ! docker ps --filter "name=^localstack$" --filter "status=running" | grep -q localstack; then
  echo "X LocalStack no está corriendo. Levántalo con:  docker compose up -d"
  exit 1
fi

docker cp scripts/avisos.sh localstack:/tmp/avisos.sh >/dev/null
docker exec localstack bash /tmp/avisos.sh
