# ==================================================================
# PASO 01 (Paso 1) - Compila el Java (Maven 21 en Docker) y corre las
# pruebas unitarias. Deja el resultado en out\lambdas.zip.
#
# Uso (desde la carpeta paso01-local):
#   .\scripts\build.ps1
#
# No necesitas Java ni Maven instalados: todo ocurre en contenedores.
# ==================================================================
$ErrorActionPreference = "Stop"
Set-Location (Split-Path $PSScriptRoot -Parent)

New-Item -ItemType Directory -Force out | Out-Null

docker build -t solicitudes-builder -f Dockerfile.builder .
if ($LASTEXITCODE -ne 0) {
    Write-Host "X Fallo el build de la imagen. Revisa el mensaje de arriba." -ForegroundColor Red
    exit 1
}

# Si quedo un contenedor temporal de una ejecucion anterior, se reutiliza el nombre
docker rm -f builder-tmp 2>$null | Out-Null
docker create --name builder-tmp solicitudes-builder | Out-Null
docker cp builder-tmp:/out/lambdas.zip out/lambdas.zip
docker rm builder-tmp | Out-Null

Write-Host ""
Write-Host "OK -> out\lambdas.zip listo." -ForegroundColor Green
Write-Host "Siguiente paso: .\scripts\init-aws.ps1 -Email tucorreo@duocuc.cl"
