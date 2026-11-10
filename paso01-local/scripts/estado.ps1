# ==================================================================
# PASO 01 (Paso 5) - Estado del sistema: tabla DynamoDB, colas SQS
# (pendientes y DLQ) y suscripciones SNS.
#
# Uso (desde la carpeta paso01-local):
#   .\scripts\estado.ps1
#
# La logica corre DENTRO del contenedor (scripts/estado.sh con awslocal).
# ==================================================================
$ErrorActionPreference = "Stop"
Set-Location (Split-Path $PSScriptRoot -Parent)

if (-not (docker ps --filter "name=^localstack$" --filter "status=running" | Select-String -Quiet "localstack")) {
    Write-Host "X LocalStack no esta corriendo. Levantalo con:  docker compose up -d" -ForegroundColor Red
    exit 1
}

docker cp scripts/estado.sh localstack:/tmp/estado.sh | Out-Null
docker exec localstack bash /tmp/estado.sh
