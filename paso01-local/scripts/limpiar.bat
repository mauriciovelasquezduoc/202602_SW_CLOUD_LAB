@echo off
rem ================================================================
rem PASO 01 - Limpieza completa: borra contenedores huerfanos de
rem Lambda, apaga LocalStack y elimina TODO el estado.
rem
rem Uso (desde la carpeta paso01-local):   scripts\limpiar.bat
rem
rem La proxima sesion: scripts\build.bat (si borraste out\) +
rem docker compose up -d + scripts\init-aws.bat tucorreo@duocuc.cl
rem ================================================================
setlocal
cd /d "%~dp0.."

echo == Contenedores huerfanos de Lambda ==
for /f %%i in ('docker ps -aq --filter "name=localstack-lambda"') do docker rm -f %%i

echo == Apagando LocalStack y borrando el estado ==
docker compose down -v

echo.
echo OK - Todo limpio. Para volver a empezar:
echo   docker compose up -d
echo   scripts\init-aws.bat tucorreo@duocuc.cl
