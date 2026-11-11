# ==================================================================
# PASO 01 (Paso 4) - Prueba de punta a punta.
# Envia un POST /solicitudes valido, muestra la respuesta 202 con
# estado RECIBIDA, y queda mirando DynamoDB hasta que la Lambda de
# procesamiento deja el item con estado PROCESADA.
#
# Uso (desde la carpeta paso01-local):
#   .\scripts\demo.ps1
#
# La logica corre DENTRO del contenedor (scripts/demo.sh con awslocal).
# ==================================================================
$ErrorActionPreference = "Stop"
Set-Location (Split-Path $PSScriptRoot -Parent)

if (-not (docker ps --filter "name=^localstack$" --filter "status=running" | Select-String -Quiet "localstack")) {
    Write-Host "X LocalStack no esta corriendo. Levantalo con:  docker compose up -d" -ForegroundColor Red
    exit 1
}

docker cp scripts/. localstack:/tmp/ | Out-Null
docker exec localstack bash /tmp/demo.sh
