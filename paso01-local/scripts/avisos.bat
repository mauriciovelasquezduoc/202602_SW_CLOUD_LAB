@echo off
rem ================================================================
rem PASO 01 (Paso 5) - Lee la "bandeja" simulada de notificaciones SNS.
rem En local no hay SMTP: las notificaciones quedan en una cola SQS
rem suscrita al topico. En el paso 02 (nube real) llegan por EMAIL.
rem
rem Uso (desde la carpeta paso01-local):   scripts\avisos.bat
rem
rem Nota: SQS hace invisible cada mensaje ~30 s tras leerlo; si acabas
rem de leer la bandeja, espera 30 s y reintenta.
rem ================================================================
setlocal
cd /d "%~dp0.."

docker ps --filter "name=^localstack$" --filter "status=running" | findstr "localstack" >nul
if errorlevel 1 (
    echo X LocalStack no esta corriendo. Levantalo con:  docker compose up -d
    exit /b 1
)

docker cp scripts/. localstack:/tmp/ >nul
docker exec localstack bash /tmp/avisos.sh
