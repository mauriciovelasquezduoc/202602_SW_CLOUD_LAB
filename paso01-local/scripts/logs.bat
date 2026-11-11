@echo off
rem ================================================================
rem PASO 01 (Paso 5) - Logs de CloudWatch de una Lambda.
rem
rem Uso (desde la carpeta paso01-local):
rem   scripts\logs.bat recepcion       (o procesamiento)
rem   scripts\logs.bat                 (sin argumento: muestra las dos)
rem
rem Nota tecnica: awslocal usa el motor del CLI v1 y NO soporta
rem "logs tail" (azucar del AWS CLI v2); se usa la API real
rem filter-log-events.
rem ================================================================
setlocal
cd /d "%~dp0.."

docker ps --filter "name=^localstack$" --filter "status=running" | findstr "localstack" >nul
if errorlevel 1 (
    echo X LocalStack no esta corriendo. Levantalo con:  docker compose up -d
    exit /b 1
)

docker cp scripts/. localstack:/tmp/ >nul

if "%~1"=="" goto dos
if not "%~1"=="recepcion" if not "%~1"=="procesamiento" goto mal
docker exec localstack awslocal logs filter-log-events --log-group-name /aws/lambda/%~1 --query "events[].message" --output text
goto fin

:dos
echo == Logs de recepcion ==
docker exec localstack awslocal logs filter-log-events --log-group-name /aws/lambda/recepcion --query "events[].message" --output text
echo.
echo == Logs de procesamiento ==
docker exec localstack awslocal logs filter-log-events --log-group-name /aws/lambda/procesamiento --query "events[].message" --output text
goto fin

:mal
echo X Lambda desconocida: "%~1". Usa "recepcion" o "procesamiento".
exit /b 1

:fin
