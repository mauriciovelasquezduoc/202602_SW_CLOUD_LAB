# ==================================================================
# Paso 01 — compilar el proyecto Java DENTRO de Docker.
#
# No necesitas JDK ni Maven instalado en tu computador:
#   make build
# genera out/lambdas.zip (el fat-jar listo para ambas funciones).
# ==================================================================

# Etapa 1: compilar y correr las pruebas unitarias con Maven + JDK 21
FROM maven:3.9-eclipse-temurin-21 AS build
WORKDIR /app
COPY java/pom.xml .
COPY java/src ./src
# corre también las pruebas unitarias (ValidadorSolicitudTest)
RUN mvn -B package

# Etapa final: empaquetar en el zip de despliegue.
# El runtime "java" de Lambda carga los .jar desde la carpeta lib/ del zip
# (CustomerClassLoader: taskRoot/ para clases sueltas + taskRoot/lib/*.jar);
# los jars sueltos en la raíz NO entran al classpath. Por eso el fat-jar
# va dentro de lib/ (igual que lo hace `sam build` para Java).
FROM build
RUN mkdir -p /out/lib \
    && cp /app/target/solicitudes-serverless-1.0.0.jar /out/lib/application.jar \
    && cd /out \
    && jar --create --file /tmp/lambdas.zip lib \
    && rm -rf lib \
    && mv /tmp/lambdas.zip /out/lambdas.zip

# make build extrae este contenido hacia out/ (sin volúmenes)
CMD ["tar", "-C", "/out", "-cf", "-", "."]
