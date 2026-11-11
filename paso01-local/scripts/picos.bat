@echo off
rem ================================================================
rem PASO 01 (Experimento: picos de trafico) - Envia N POST seguidos
rem (10 por defecto) y muestra el codigo HTTP real de cada uno.
rem Uso (desde cualquier carpeta):
rem   scripts\picos.bat           (10 solicitudes)
rem   scripts\picos.bat 50        (50 solicitudes)
rem ================================================================
setlocal enabledelayedexpansion
cd /d "%~dp0.."

set "N=%~1"
if "%N%"=="" set "N=10"

docker ps --filter "name=^localstack$" --filter "status=running" | findstr "localstack" >nul
if errorlevel 1 (
    echo X LocalStack no esta corriendo. Levantalo con:  docker compose up -d
    exit /b 1
)

if not exist "ejemplo-valido.json" (
    echo X No encuentro ejemplo-valido.json ^(debe estar en paso01-local^).
    exit /b 1
)

for /f "delims=" %%a in ('docker exec localstack awslocal apigateway get-rest-apis --query "items[0].id" --output text') do set "API=%%a"
set "URL=http://localhost:4566/restapis/%API%/prod/_user_request_/solicitudes"

for /l %%i in (1,1,%N%) do (
    for /f %%c in ('curl.exe -s -o NUL -w "%%{http_code}" -X POST "%URL%" -H "Content-Type: application/json" -d "@ejemplo-valido.json"') do set "CODE=%%c"
    echo solicitud %%i -^> HTTP !CODE!
)
if not defined CODE set "CODE=?"

echo.
echo == Estado de la cola tras el pico ==
docker exec localstack awslocal sqs get-queue-attributes --queue-url "http://localhost:4566/000000000000/solicitudes-pendientes" --attribute-names ApproximateNumberOfMessages ApproximateNumberOfMessagesNotVisible --query "Attributes" --output table
