# ==================================================================
# PASO 01 (Paso 5) - Logs de CloudWatch de una Lambda.
#
# Uso (desde la carpeta paso01-local):
#   .\scripts\logs.ps1 recepcion       # logs de la Lambda de recepcion
#   .\scripts\logs.ps1 procesamiento   # logs de la Lambda de procesamiento
#   .\scripts\logs.ps1                 # sin argumento: muestra las dos
#
# Nota tecnica: awslocal usa el motor del CLI v1 y NO soporta
# "logs tail" (azucar del AWS CLI v2); se usa la API real
# filter-log-events.
# ==================================================================
param([string]$Lambda = "")

$ErrorActionPreference = "Stop"
Set-Location (Split-Path $PSScriptRoot -Parent)

if (-not (docker ps --filter "name=^localstack$" --filter "status=running" | Select-String -Quiet "localstack")) {
    Write-Host "X LocalStack no esta corriendo. Levantalo con:  docker compose up -d" -ForegroundColor Red
    exit 1
}

docker cp scripts/. localstack:/tmp/ | Out-Null

if ($Lambda -eq "") {
    $FNs = @("recepcion", "procesamiento")
}
elseif ($Lambda -in @("recepcion", "procesamiento")) {
    $FNs = @($Lambda)
}
else {
    Write-Host "X Lambda desconocida: '$Lambda'. Usa 'recepcion' o 'procesamiento'." -ForegroundColor Red
    exit 1
}

foreach ($FN in $FNs) {
    Write-Host "== Logs de $FN =="
    docker exec localstack awslocal logs filter-log-events --log-group-name "/aws/lambda/$FN" --query 'events[].message' --output text
    Write-Host ""
}
