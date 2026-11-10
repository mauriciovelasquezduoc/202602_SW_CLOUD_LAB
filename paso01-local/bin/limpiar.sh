#!/usr/bin/env bash
# ==================================================================
# PASO 01 - Limpieza completa: borra contenedores huérfanos de
# Lambda, apaga LocalStack y elimina TODO el estado.
#
# Uso (desde la carpeta paso01-local):  ./bin/limpiar.sh
#
# La próxima sesión: ./bin/build.sh (si borraste out/) +
# docker compose up -d + ./bin/init-aws.sh tucorreo@duocuc.cl
# ==================================================================
set -e
cd "$(dirname "$0")/.."

echo "== Contenedores huérfanos de Lambda =="
ids=$(docker ps -aq --filter "name=localstack-lambda" || true)
if [ -n "$ids" ]; then
  docker rm -f $ids
else
  echo "(ninguno)"
fi

echo "== Apagando LocalStack y borrando el estado =="
docker compose down -v

echo
echo "OK - Todo limpio. Para volver a empezar:"
echo "  docker compose up -d"
echo "  ./bin/init-aws.sh tucorreo@duocuc.cl"
