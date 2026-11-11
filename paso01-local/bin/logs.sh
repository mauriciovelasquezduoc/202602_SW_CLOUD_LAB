#!/usr/bin/env bash
# ==================================================================
# PASO 01 (Paso 5) - Logs de CloudWatch de una Lambda.
#
# Uso (desde la carpeta paso01-local):
#   ./bin/logs.sh recepcion       # logs de la Lambda de recepción
#   ./bin/logs.sh procesamiento   # logs de la Lambda de procesamiento
#   ./bin/logs.sh                 # sin argumento: muestra las dos
#
# Nota técnica: awslocal usa el motor del CLI v1 y NO soporta
# "logs tail" (azúcar del AWS CLI v2); se usa la API real
# filter-log-events.
# ==================================================================
set -e
cd "$(dirname "$0")/.."

if ! docker ps --filter "name=^localstack$" --filter "status=running" | grep -q localstack; then
  echo "X LocalStack no está corriendo. Levántalo con:  docker compose up -d"
  exit 1
fi

docker cp scripts/. localstack:/tmp/ >/dev/null

VER="${1:-}"
case "$VER" in
  "") FN_LIST="recepcion procesamiento" ;;
  recepcion|procesamiento) FN_LIST="$VER" ;;
  *) echo "X Lambda desconocida: '$VER'. Usa 'recepcion' o 'procesamiento'."; exit 1 ;;
esac

for FN in $FN_LIST; do
  echo "== Logs de $FN =="
  docker exec localstack awslocal logs filter-log-events \
    --log-group-name "/aws/lambda/$FN" \
    --query 'events[].message' --output text
  echo
done
