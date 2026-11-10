@echo off
rem ================================================================
rem PASO 01 (Paso 5) - Estado del sistema: tabla DynamoDB, colas SQS
rem (pendientes y DLQ) y suscripciones SNS.
rem
rem Uso (desde la carpeta paso01-local):   scripts\estado.bat
rem
rem La logica corre DENTRO del contenedor (scripts/estado.sh con awslocal).
rem ================================================================
setlocal
cd /d "%~dp0.."

docker ps --filter "name=^localstack$" --filter "status=running" | findstr "localstack" >nul
if errorlevel 1 (
    echo X LocalStack no esta corriendo. Levantalo con:  docker compose up -d
    exit /b 1
)

docker cp scripts/estado.sh localstack:/tmp/estado.sh
docker exec localstack bash /tmp/estado.sh
