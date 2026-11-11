#!/usr/bin/env bash
# ==================================================================
# PASO 01 (Experimento: picos de tráfico) - Envía N POST seguidos
# (10 por defecto) y muestra el código HTTP real de cada uno.
# Todos deben responder 202 al instante aunque el procesamiento
# Java tarde: la cola amortigua el pico. Al final muestra el estado
# de la cola para ver (o no) los mensajes drenándose.
#
# Uso (desde cualquier carpeta):
#   ./bin/picos.sh          # 10 solicitudes
#   ./bin/picos.sh 50       # 50 solicitudes
# ==================================================================
set -e
cd "$(dirname "$0")/.."

N="${1:-10}"
case "$N" in *[!0-9]*|"") echo "X La cantidad debe ser un número:  ./bin/picos.sh 10"; exit 1;; esac

if ! docker ps --filter "name=^localstack$" --filter "status=running" | grep -q localstack; then
  echo "X LocalStack no está corriendo. Levántalo con:  docker compose up -d"
  exit 1
fi

[ -f ejemplo-valido.json ] || { echo "X No encuentro ejemplo-valido.json (debe estar en paso01-local)."; exit 1; }

api=$(docker exec localstack awslocal apigateway get-rest-apis --query "items[0].id" --output text)
url="http://localhost:4566/restapis/$api/prod/_user_request_/solicitudes"

for i in $(seq 1 "$N"); do
  code=$(curl -s -o /dev/null -w "%{http_code}" -X POST "$url" -H "Content-Type: application/json" -d @ejemplo-valido.json)
  echo "solicitud $i -> HTTP $code"
done

echo
echo "== Estado de la cola tras el pico (corre 'estado' rápido si quieres ver drenar) =="
docker exec localstack awslocal sqs get-queue-attributes \
  --queue-url "http://localhost:4566/000000000000/solicitudes-pendientes" \
  --attribute-names ApproximateNumberOfMessages ApproximateNumberOfMessagesNotVisible \
  --query 'Attributes' --output table
