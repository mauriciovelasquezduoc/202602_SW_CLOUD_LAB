#!/usr/bin/env bash
# ==================================================================
# Paso 01 — prueba de punta a punta.
#
# Normalmente NO lo ejecutas a mano: usa el wrapper de tu sistema,
# que copia los scripts y lo ejecuta dentro del contenedor:
#   macOS/Linux:      ./bin/demo.sh
#   Windows (PS/CMD): scripts\demo.ps1  |  scripts\demo.bat
# ==================================================================
set -e

API_ID=$(awslocal apigateway get-rest-apis --query 'items[0].id' --output text 2>/dev/null || true)
if [ -z "$API_ID" ] || [ "$API_ID" = "None" ]; then
  echo "No hay API todavía. Primero crea la infraestructura (Paso 3 del README)."
  exit 1
fi

URL="http://localhost:4566/restapis/${API_ID}/prod/_user_request_/solicitudes"

echo ">> POST $URL"
echo
RESPUESTA=$(curl -sS -X POST "$URL" -H "Content-Type: application/json" -d '{
  "alumno": { "nombre": "María Pérez Soto", "email": "maria.perez@duocuc.cl" },
  "tipo": "CERTIFICADO",
  "descripcion": "Necesito certificado de notas para postular a una beca"
}')

echo "Respuesta del sistema (HTTP 202 Accepted, aún NO procesada):"
echo "$RESPUESTA"
echo

echo ">> Esperando el procesamiento asíncrono (hasta 3 min por el cold start de Java) ..."
for i in $(seq 1 45); do
  COUNT=$(awslocal dynamodb scan \
    --table-name solicitudes \
    --filter-expression '#e = :p' \
    --expression-attribute-names '{"#e":"estado"}' \
    --expression-attribute-values '{":p":{"S":"PROCESADA"}}' \
    --query 'Count' --output text 2>/dev/null) || COUNT=0
  if [ "$COUNT" -ge 1 ] 2>/dev/null; then
    echo
    echo ">> Solicitud PROCESADA y notificada. Contenido de la tabla DynamoDB:"
    awslocal dynamodb scan --table-name solicitudes \
      --query 'Items[].{id:solicitudId.S, tipo:tipo.S, estado:estado.S, alumno:nombreAlumno.S, email:emailAlumno.S, resultado:resultado.S, procesada:fechaProcesamiento.S}' \
      --output table
    echo ">> El 'correo' de SNS:  ./bin/avisos.sh  (mac/linux) | scripts\\avisos.ps1  (Windows)"
    exit 0
  fi
  printf "."
  sleep 4
done

echo
echo ">> Sigue pendiente. Es normal la PRIMERA vez (imagen de Java se descarga)."
echo ">> Reintenta en 1 minuto:  ./bin/demo.sh  (mac/linux) | scripts\\demo.ps1  (Windows)"
echo ">> Logs: docker exec localstack awslocal logs tail /aws/lambda/procesamiento --since 15m --format short"
