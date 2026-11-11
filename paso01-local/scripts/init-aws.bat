@echo off
rem ================================================================
rem PASO 01 (Paso 3) - Crea TODA la infraestructura dentro de
rem LocalStack (SQS + DLQ, DynamoDB, SNS, las dos Lambdas Java, el
rem event source mapping y la API Gateway). Es IDEMPOTENTE.
rem
rem Uso (desde la carpeta paso01-local):
rem   scripts\init-aws.bat tucorreo@duocuc.cl
rem
rem La logica corre DENTRO del contenedor (scripts/init-aws.sh con
rem awslocal); este wrapper solo copia los archivos y lo ejecuta.
rem ================================================================
setlocal
cd /d "%~dp0.."

set "EMAIL=%~1"
if "%EMAIL%"=="" set "EMAIL=alumno@duocuc.cl"

if not exist "out\lambdas.zip" (
    echo X Falta out\lambdas.zip. Compila primero:  scripts\build.bat
    exit /b 1
)

docker ps --filter "name=^localstack$" --filter "status=running" | findstr "localstack" >nul
if errorlevel 1 (
    echo X LocalStack no esta corriendo. Levantalo con:  docker compose up -d
    exit /b 1
)

docker cp out/lambdas.zip localstack:/tmp/lambdas.zip >nul
docker cp scripts/. localstack:/tmp/ >nul
docker exec -e EMAIL_NOTIFICATIONS=%EMAIL% localstack bash /tmp/init-aws.sh
