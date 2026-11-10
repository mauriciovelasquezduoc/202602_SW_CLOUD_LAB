#!/usr/bin/env bash
# ==================================================================
# PASO 01 (Paso 1) - Compila el Java (Maven 21 en Docker) y corre
# las pruebas unitarias. Deja el resultado en out/lambdas.zip.
#
# Uso (desde la carpeta paso01-local):  ./bin/build.sh
#
# No necesitas Java ni Maven instalados: todo corre en contenedores.
# ==================================================================
set -e
cd "$(dirname "$0")/.."

mkdir -p out

docker build -t solicitudes-builder -f Dockerfile.builder .

# Si quedó un contenedor temporal de una ejecución anterior, reutiliza el nombre
docker rm -f builder-tmp >/dev/null 2>&1 || true
docker create --name builder-tmp solicitudes-builder >/dev/null
docker cp builder-tmp:/out/lambdas.zip out/lambdas.zip
docker rm builder-tmp >/dev/null

echo
echo "OK -> out/lambdas.zip listo."
echo "Siguiente paso:  ./bin/init-aws.sh tucorreo@duocuc.cl"
