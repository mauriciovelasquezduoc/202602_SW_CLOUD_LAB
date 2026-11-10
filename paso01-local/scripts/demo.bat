@echo off
rem ================================================================
rem PASO 01 (Paso 4) - Prueba de punta a punta.
rem Envia un POST /solicitudes valido, muestra la respuesta 202 con
rem estado RECIBIDA, y queda mirando DynamoDB hasta que la Lambda de
rem procesamiento deja el item con estado PROCESADA.
rem
rem Uso (desde la carpeta paso01-local):   scripts\demo.bat
rem
rem La logica corre DENTRO del contenedor (scripts/demo.sh con awslocal).
rem ================================================================
setlocal
cd /d "%~dp0.."

docker ps --filter "name=^localstack$" --filter "status=running" | findstr "localstack" >nul
if errorlevel 1 (
    echo X LocalStack no esta corriendo. Levantalo con:  docker compose up -d
    exit /b 1
)

docker cp scripts/demo.sh localstack:/tmp/demo.sh
docker exec localstack bash /tmp/demo.sh
