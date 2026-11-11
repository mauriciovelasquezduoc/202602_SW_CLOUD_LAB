# ==================================================================
# PASO 01 (Experimento: picos de trafico) - Envia N POST seguidos
# (10 por defecto) y muestra el codigo HTTP real de cada uno.
# Uso (desde cualquier carpeta):
#   .\scripts\picos.ps1          # 10 solicitudes
#   .\scripts\picos.ps1 50       # 50 solicitudes
# ==================================================================
param([int]$N = 10)

$ErrorActionPreference = "Stop"
Set-Location (Split-Path $PSScriptRoot -Parent)

if (-not (docker ps --filter "name=^localstack$" --filter "status=running" | Select-String -Quiet "localstack")) {
    Write-Host "X LocalStack no esta corriendo. Levantalo con:  docker compose up -d" -ForegroundColor Red
    exit 1
}

if (-not (Test-Path "ejemplo-valido.json")) {
    Write-Host "X No encuentro ejemplo-valido.json (debe estar en paso01-local)." -ForegroundColor Red
    exit 1
}

$api = (docker exec localstack awslocal apigateway get-rest-apis --query "items[0].id" --output text)
$url = "http://localhost:4566/restapis/$api/prod/_user_request_/solicitudes"

1..$N | ForEach-Object {
    $code = curl.exe -s -o NUL -w "%{http_code}" -X POST $url -H "Content-Type: application/json" -d "@ejemplo-valido.json"
    "solicitud $_ -> HTTP $code"
}

Write-Host ""
Write-Host "== Estado de la cola tras el pico =="
docker exec localstack awslocal sqs get-queue-attributes --queue-url "http://localhost:4566/000000000000/solicitudes-pendientes" --attribute-names ApproximateNumberOfMessages ApproximateNumberOfMessagesNotVisible --query 'Attributes' --output table
