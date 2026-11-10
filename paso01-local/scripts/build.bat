@echo off
rem ================================================================
rem PASO 01 (Paso 1) - Compila el Java (Maven 21 en Docker) y corre
rem las pruebas unitarias. Deja el resultado en out\lambdas.zip.
rem
rem Uso (desde la carpeta paso01-local):   scripts\build.bat
rem No necesitas Java ni Maven instalados: todo corre en contenedores.
rem ================================================================
setlocal
cd /d "%~dp0.."

if not exist out mkdir out

docker build -t solicitudes-builder -f Dockerfile.builder .
if errorlevel 1 (
    echo X Fallo el build de la imagen. Revisa el mensaje de arriba.
    exit /b 1
)

rem Si quedo un contenedor temporal de una ejecucion anterior, se reutiliza el nombre
docker rm -f builder-tmp >nul 2>&1
docker create --name builder-tmp solicitudes-builder >nul
docker cp builder-tmp:/out/lambdas.zip out/lambdas.zip
docker rm builder-tmp >nul

echo.
echo OK - out\lambdas.zip listo.
echo Siguiente paso:  scripts\init-aws.bat tucorreo@duocuc.cl
