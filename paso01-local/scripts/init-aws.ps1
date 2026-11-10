# ==================================================================
# PASO 01 (Paso 3) - Crea TODA la infraestructura dentro de LocalStack
# (SQS + DLQ, DynamoDB, SNS, las dos Lambdas Java, el event source
# mapping y la API Gateway). Es IDEMPOTENTE: si ya existe, la reutiliza
# y actualiza el codigo de las Lambdas con el build mas reciente.
#
# Uso (desde la carpeta paso01-local):
#   .\scripts\init-aws.ps1 -Email tucorreo@duocuc.cl
#
# La logica corre DENTRO del contenedor (scripts/init-aws.sh con awslocal);
# este wrapper solo copia los archivos y lo ejecuta.
# ==================================================================
param([string]$Email = "alumno@duocuc.cl")

$ErrorActionPreference = "Stop"
Set-Location (Split-Path $PSScriptRoot -Parent)

if (-not (Test-Path "out\lambdas.zip")) {
    Write-Host "X Falta out\lambdas.zip. Compila primero:  .\scripts\build.ps1" -ForegroundColor Red
    exit 1
}

if (-not (docker ps --filter "name=^localstack$" --filter "status=running" | Select-String -Quiet "localstack")) {
    Write-Host "X LocalStack no esta corriendo. Levantalo con:  docker compose up -d" -ForegroundColor Red
    exit 1
}

docker cp out/lambdas.zip localstack:/tmp/lambdas.zip | Out-Null
docker cp scripts/init-aws.sh localstack:/tmp/init-aws.sh | Out-Null
docker exec -e EMAIL_NOTIFICATIONS=$Email localstack bash /tmp/init-aws.sh
