#!/usr/bin/env bash
# ==================================================================
# Paso 01 — estado del sistema dentro de LocalStack.
# Se ejecuta con: docker exec -i localstack bash < scripts/estado.sh
# ==================================================================
NOMBRE_TABLA=solicitudes

echo "=== DynamoDB: solicitudes registradas ==="
awslocal dynamodb scan --table-name "$NOMBRE_TABLA" \
  --query 'Items[].{id:solicitudId.S, tipo:tipo.S, estado:estado.S, alumno:nombreAlumno.S, resultado:resultado.S}' \
  --output table 2>/dev/null || echo "(tabla sin datos; envia una solicitud con make demo)"

echo
echo "=== SQS: mensajes pendientes y DLQ ==="
awslocal sqs get-queue-attributes \
  --queue-url "http://localhost:4566/000000000000/solicitudes-pendientes" \
  --attribute-names ApproximateNumberOfMessages ApproximateNumberOfMessagesNotVisible \
  --query 'Attributes' --output table 2>/dev/null || true

awslocal sqs get-queue-attributes \
  --queue-url "http://localhost:4566/000000000000/solicitudes-dlq" \
  --attribute-names ApproximateNumberOfMessages \
  --query 'Attributes' --output table 2>/dev/null || true

echo
echo "=== SNS: suscripciones ==="
awslocal sns list-subscriptions \
  --query 'Subscriptions[].{Protocolo:Protocol, Endpoint:Endpoint, Estado:SubscriptionArn}' \
  --output table 2>/dev/null || true

echo
echo "=== SNS: bandeja simulada (lo que en la nube llega por email) ==="
awslocal sqs receive-message \
  --queue-url "http://localhost:4566/000000000000/notificaciones-bandeja" \
  --max-number-of-messages 5 \
  --query 'length(Messages)? 0 : length(Messages)' --output text 2>/dev/null || true
echo "(usa 'make avisos' para leer las notificaciones en detalle)"
