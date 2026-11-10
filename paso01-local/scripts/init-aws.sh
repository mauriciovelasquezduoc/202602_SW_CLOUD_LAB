#!/usr/bin/env bash
# ==================================================================
# Paso 01 — crea TODA la arquitectura dentro del contenedor LocalStack.
#
# Este script NO corre en tu Mac: el Makefile lo envía al contenedor:
#   docker exec -i -e EMAIL_NOTIFICATIONS=... localstack bash < scripts/init-aws.sh
#
# Es IDEMPOTENTE: si algo ya existe lo reutiliza; si el zip cambió,
# actualiza el código de las Lambdas. Total compatibilidad conceptual
# con el template SAM del paso en la nube:
#   TablaSolicitudes      -> DynamoDB "solicitudes"
#   ColaSolicitudes + DLQ -> SQS "solicitudes-pendientes" y "solicitudes-dlq"
#   TopicoNotificaciones  -> SNS "notificaciones" (suscripción email simulada)
#   ApiSolicitudes        -> API Gateway REST "solicitudes-api" (POST /solicitudes)
#   FuncionRecepcion      -> Lambda Java 21 "recepcion"
#   FuncionProcesamiento  -> Lambda Java 21 "procesamiento" + event source mapping
# ==================================================================
set -e

REGION="us-east-1"
CUENTA="000000000000"

echo "== 0. Estado previo =="
if [ -f /tmp/lambdas.zip ]; then
  echo ">> Sincronizando código actual de las Lambdas (idempotente) ..."
  awslocal lambda update-function-code --function-name recepcion \
    --zip-file fileb:///tmp/lambdas.zip --region "$REGION" > /dev/null 2>&1 \
    || echo "   (recepcion no existe aún: se creará más abajo)"
  awslocal lambda update-function-code --function-name procesamiento \
    --zip-file fileb:///tmp/lambdas.zip --region "$REGION" > /dev/null 2>&1 \
    || echo "   (procesamiento no existe aún: se creará más abajo)"
fi

if API_ID_PREVIO=$(awslocal apigateway get-rest-apis --query 'items[0].id' --output text 2>/dev/null) \
   && [ -n "$API_ID_PREVIO" ] && [ "$API_ID_PREVIO" != "None" ]; then
  echo ">> La API ya existe ($API_ID_PREVIO): la infraestructura está completa."
  # garantizar la bandeja simulada de notificaciones (agregada después)
  if ! awslocal sqs get-queue-url --queue-name notificaciones-bandeja --region "$REGION" > /dev/null 2>&1; then
    echo ">> Creando 'bandeja' simulada de SNS que faltaba ..."
    awslocal sqs create-queue --queue-name notificaciones-bandeja --region "$REGION" > /dev/null
    TOPICO_EXISTENTE=$(awslocal sns list-topics --query 'Topics[0].TopicArn' --output text --region "$REGION" 2>/dev/null)
    [ -n "$TOPICO_EXISTENTE" ] && [ "$TOPICO_EXISTENTE" != "None" ] \
      && awslocal sns subscribe --topic-arn "$TOPICO_EXISTENTE" --protocol sqs \
           --notification-endpoint "arn:aws:sqs:${REGION}:${CUENTA}:notificaciones-bandeja" \
           --region "$REGION" > /dev/null || true
  fi
  echo ">> Usa 'make demo' directamente, o re-crea todo desde cero con:"
  echo ">>   make down && make up && make init"
  exit 0
fi

echo "== 1. SQS: cola de pendientes + DLQ =="
DLQ_ARN=$(awslocal sqs create-queue --queue-name solicitudes-dlq --region "$REGION" --query QueueArn --output text)
QUEUE_URL=$(awslocal sqs create-queue --queue-name solicitudes-pendientes --region "$REGION" --query QueueUrl --output text)
QUEUE_ARN="arn:aws:sqs:${REGION}:${CUENTA}:solicitudes-pendientes"

# Visibilidad debe cubrir el cold start de Java; tras 3 intentos fallidos -> DLQ
ATTRS=$(cat <<EOF
{"VisibilityTimeout":"120","RedrivePolicy":"{\"deadLetterTargetArn\":\"${DLQ_ARN}\",\"maxReceiveCount\":3}"}
EOF
)
awslocal sqs set-queue-attributes --queue-url "$QUEUE_URL" --attributes "$ATTRS" > /dev/null

echo "== 2. DynamoDB: tabla de solicitudes =="
awslocal dynamodb create-table \
  --table-name solicitudes \
  --attribute-definitions AttributeName=solicitudId,AttributeType=S \
  --key-schema AttributeName=solicitudId,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST \
  --region "$REGION" > /dev/null 2>&1 \
  || echo "   (tabla ya existía: se reutiliza)"

echo "== 3. SNS: tópico de notificaciones + suscripciones =="
TOPICO_ARN=$(awslocal sns create-topic --name notificaciones --region "$REGION" --query TopicArn --output text)
# (a) suscripcion email: igual que en la nube (en local no hay SMTP real, no entrega)
awslocal sns subscribe \
  --topic-arn "$TOPICO_ARN" \
  --protocol email \
  --notification-endpoint "${EMAIL_NOTIFICATIONS:-alumno@duocuc.cl}" \
  --region "$REGION" > /dev/null || true
# (b) "bandeja" local: una cola SQS suscrita al tópico emula el buzón.
#     En la nube el alumno recibe el email; en el paso 01 se lee con 'make avisos'.
awslocal sqs create-queue --queue-name notificaciones-bandeja --region "$REGION" > /dev/null
awslocal sns subscribe \
  --topic-arn "$TOPICO_ARN" \
  --protocol sqs \
  --notification-endpoint "arn:aws:sqs:${REGION}:${CUENTA}:notificaciones-bandeja" \
  --region "$REGION" > /dev/null || true || true

echo "== 4. Lambdas Java 21 (el zip está en /tmp, copiado por el Makefile) =="
FIN_RECEPTION=$(awslocal lambda create-function \
  --function-name recepcion \
  --zip-file fileb:///tmp/lambdas.zip \
  --handler duoc.cloud.solicitudes.RecepcionHandler::handleRequest \
  --runtime java21 \
  --timeout 120 \
  --memory-size 1024 \
  --role "arn:aws:iam::${CUENTA}:role/dummy" \
  --environment '{"Variables":{"AWS_ENDPOINT_URL":"http://localstack:4566","AWS_REGION":"us-east-1","AWS_ACCESS_KEY_ID":"test","AWS_SECRET_ACCESS_KEY":"test","COLA_SOLICITUDES_URL":"http://localstack:4566/000000000000/solicitudes-pendientes"}}' \
  --region "$REGION" --query FunctionName --output text 2>/dev/null \
  || true)
if [ -z "$FIN_RECEPTION" ]; then
  echo "   (recepcion ya existía: actualizando el código)"
  awslocal lambda update-function-code --function-name recepcion \
    --zip-file fileb:///tmp/lambdas.zip --region "$REGION" > /dev/null
fi

FIN_PROC=$(awslocal lambda create-function \
  --function-name procesamiento \
  --zip-file fileb:///tmp/lambdas.zip \
  --handler duoc.cloud.solicitudes.ProcesamientoHandler::handleRequest \
  --runtime java21 \
  --timeout 120 \
  --memory-size 1024 \
  --role "arn:aws:iam::${CUENTA}:role/dummy" \
  --environment '{"Variables":{"AWS_ENDPOINT_URL":"http://localstack:4566","AWS_REGION":"us-east-1","AWS_ACCESS_KEY_ID":"test","AWS_SECRET_ACCESS_KEY":"test","TABLA_SOLICITUDES":"solicitudes","TOPICO_NOTIFICACIONES":"'${TOPICO_ARN}'"}}' \
  --region "$REGION" --query FunctionName --output text 2>/dev/null \
  || true)
if [ -z "$FIN_PROC" ]; then
  echo "   (procesamiento ya existía: actualizando el código)"
  awslocal lambda update-function-code --function-name procesamiento \
    --zip-file fileb:///tmp/lambdas.zip --region "$REGION" > /dev/null
fi

echo "== 5. SQS activa la Lambda de procesamiento (event source mapping) =="
awslocal lambda create-event-source-mapping \
  --function-name procesamiento \
  --event-source-arn "$QUEUE_ARN" \
  --batch-size 5 \
  --region "$REGION" > /dev/null 2>&1 \
  || echo "   (mapping ya existía: se reutiliza)"

echo "== 6. API Gateway REST + integración proxy con la Lambda de recepción =="
API_ID=$(awslocal apigateway create-rest-api --name solicitudes-api --region "$REGION" --query id --output text)
ROOT_ID=$(awslocal apigateway get-resources --rest-api-id "$API_ID" --region "$REGION" --query 'items[?path==`/`].id' --output text)
RES_ID=$(awslocal apigateway create-resource --rest-api-id "$API_ID" --parent-id "$ROOT_ID" --path-part solicitudes --region "$REGION" --query id --output text)

awslocal apigateway put-method \
  --rest-api-id "$API_ID" --resource-id "$RES_ID" \
  --http-method POST --authorization-type NONE \
  --region "$REGION" > /dev/null

awslocal apigateway put-integration \
  --rest-api-id "$API_ID" --resource-id "$RES_ID" --http-method POST \
  --type AWS_PROXY --integration-http-method POST \
  --uri "arn:aws:apigateway:${REGION}:lambda:path/2015-03-31/functions/arn:aws:lambda:${REGION}:${CUENTA}:function:recepcion/invocations" \
  --region "$REGION" > /dev/null

awslocal lambda add-permission \
  --function-name recepcion --statement-id apigw-invoke \
  --action lambda:InvokeFunction --principal apigateway.amazonaws.com \
  --region "$REGION" > /dev/null || true

awslocal apigateway create-deployment --rest-api-id "$API_ID" --stage-name prod --region "$REGION" > /dev/null

echo
echo "============================================================"
echo " Infraestructura local lista. Registra una solicitud con:"
echo "   make demo"
echo " URL de la API:"
echo "   http://localhost:4566/restapis/${API_ID}/prod/_user_request_/solicitudes"
echo "============================================================"
