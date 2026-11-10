# ==============================================================
# Paso 01 — correr TODA la arquitectura local en Docker.
# Único prerrequisito: Docker (no necesitas Java, Maven ni AWS CLI).
#
#   make help      lista de comandos
#   make build     compila el código Java Lambda en un contenedor
#   make up        levanta LocalStack (AWS local)
#   make init      crea colas, tabla, tópico, Lambdas y API
#   make demo      POST /solicitudes de punta a punta
#   make estado    tabla DynamoDB + colas SQS + suscripciones SNS
#   make down      apaga y borra todo
# ==============================================================

SHELL := /bin/bash

.PHONY: help build up init demo estado down purge limpiar url shell \
        logs-recepcion logs-procesamiento

help:
	@echo "PASO 01 - sistema de solicitudes 100% local (Docker)"
	@echo
	@echo "  make build          compila el Java Lambda + pruebas unitarias  -> out/lambdas.zip"
	@echo "  make up             levanta LocalStack en http://localhost:4566"
	@echo "  make init           crea la infraestructura (idempotente; con estado previo no toca nada)"
	@echo "                      opcional:  make init EMAIL=alumno@duocuc.cl"
	@echo "  make demo           envia un POST /solicitudes y verifica el ciclo completo"
	@echo "  make estado         muestra DynamoDB, colas SQS y SNS"
	@echo "  make avisos         lee la 'bandeja' de notificaciones (el email simulado)"
	@echo "  make logs-recepcion / logs-procesamiento   logs CloudWatch de cada Lambda"
	@echo "  make url            imprime la URL de la API (para Postman)"
	@echo "  make limpiar        limpia out/ (zips compilados)"
	@echo "  make purge          borra tambien contenedores lambda huerfanos"
	@echo "  make down           apaga LocalStack y borra TODO el estado"

# ---------- 1. compilar ----------
build:
	mkdir -p out
	docker build -t solicitudes-builder -f Dockerfile.builder .
	docker run --rm solicitudes-builder | tar -xf - -C out
	@echo ""
	@echo ">> Listo: out/lambdas.zip contiene el fat-jar con las dos Lambdas."
	@echo ">> Siguiente paso: make up"

# (las pruebas unitarias corren automáticamente dentro de 'make build',
#  a través de Maven: mvn package -> surefire)

# ---------- 2. levantar LocalStack ----------
up:
	docker compose up -d
	@echo ">> Esperando LocalStack ..."
	@until curl -sf http://localhost:4566/_localstack/health > /dev/null; do printf "."; sleep 1; done
	@echo ""
	@echo ">> LocalStack listo en http://localhost:4566"
	@echo ">> Siguiente paso: make init"

# ---------- 3. crear la infraestructura ----------
init:
	@[ -f out/lambdas.zip ] || { echo "Falta compilar: corre primero 'make build'"; exit 1; }
	docker cp out/lambdas.zip localstack:/tmp/lambdas.zip
	docker exec -i -e EMAIL_NOTIFICATIONS="$(EMAIL)" localstack bash < scripts/init-aws.sh

# ---------- 4. demo punta a punta ----------
demo:
	bash scripts/demo.sh

estado:
	docker exec -i localstack bash < scripts/estado.sh

avisos:
	docker exec -i localstack bash < scripts/avisos.sh

logs-recepcion:
	docker exec localstack awslocal logs tail /aws/lambda/recepcion --since 15m --format short

logs-procesamiento:
	docker exec localstack awslocal logs tail /aws/lambda/procesamiento --since 15m --format short

url:
	@echo "http://localhost:4566/restapis/$$(docker exec localstack awslocal apigateway get-rest-apis --query 'items[0].id' --output text)/prod/_user_request_/solicitudes"

shell:
	docker exec -it localstack bash

# ---------- 5. limpieza ----------
limpiar:
	rm -rf out

purge:
	-@docker rm -f $$(docker ps -aq --filter "name=localstack-lambda") 2>/dev/null || true

down: purge
	docker compose down -v
	@echo ">> LocalStack eliminado. La proxima sesion: make build (si borraste out/) + make up + make init"
