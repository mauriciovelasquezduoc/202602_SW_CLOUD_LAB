# ==================================================================
# PASO 01 (Paso 5) - Lee la "bandeja" simulada de notificaciones SNS.
# En local no hay SMTP: las notificaciones quedan en una cola SQS
# suscrita al topico. En el paso 02 (nube real) llegan por EMAIL.
#
# Uso (desde la carpeta paso01-local):
#   .\scripts\avisos.ps1
#
# Nota: SQS hace invisible cada mensaje ~30 s tras leerlo; si acabas
# de leer la bandeja, espera 30 s y reintenta.
# ==================================================================
$ErrorActionPreference = "Stop"
Set-Location (Split-Path $PSScriptRoot -Parent)

if (-not (docker ps --filter "name=^localstack$" --filter "status=running" | Select-String -Quiet "localstack")) {
    Write-Host "X LocalStack no esta corriendo. Levantalo con:  docker compose up -d" -ForegroundColor Red
    exit 1
}

docker cp scripts/. localstack:/tmp/ | Out-Null
docker exec localstack bash /tmp/avisos.sh
