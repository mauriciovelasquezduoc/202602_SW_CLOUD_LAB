# ==================================================================
# PASO 01 - Limpieza completa: borra contenedores huerfanos de Lambda,
# apaga LocalStack y elimina TODO el estado (colas, tabla, logs).
#
# Uso (desde la carpeta paso01-local):
#   .\scripts\limpiar.ps1
#
# La proxima sesion: .\scripts\build.ps1 (si borraste out\) +
# docker compose up -d + .\scripts\init-aws.ps1 -Email ...
# ==================================================================
$ErrorActionPreference = "Stop"
Set-Location (Split-Path $PSScriptRoot -Parent)

Write-Host "== Contenedores huerfanos de Lambda =="
$huorfanos = docker ps -aq --filter "name=localstack-lambda"
if ($huorfanos) { $huorfanos | ForEach-Object { docker rm -f $_ } | Out-Null }
else { Write-Host "(ninguno)" }

Write-Host "== Apagando LocalStack y borrando el estado =="
docker compose down -v

Write-Host ""
Write-Host "OK - Todo limpio. Para volver a empezar:" -ForegroundColor Green
Write-Host "  docker compose up -d"
Write-Host "  .\scripts\init-aws.ps1 -Email tucorreo@duocuc.cl"
