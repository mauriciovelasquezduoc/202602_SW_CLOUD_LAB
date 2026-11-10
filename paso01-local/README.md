# PASO 01 · Guía: correr TODO el sistema local en Docker (Windows, sin `make`)

El mismo sistema de solicitudes que luego desplegarás en AWS real (paso 02), pero 100% en tu computador:

```
                ┌────────────────── DOCKER ──────────────────────────┐
curl / Postman  │                                                    │
   │            │   LocalStack (localhost:4566)                       │
   │ POST       │   ┌──────────────────────────────────────────┐      │
   └────────────┼──►│ API Gateway REST  ·  POST /solicitudes   │      │
                │   └────────────────┬─────────────────────────┘      │
                │                    │ invoca                         │
                │                    ▼                                │
                │   ┌──────────────────────────────────────────┐      │
                │   │ CONTENEDOR Lambda Java 21 ( recepción )  │      │
                │   │ valida → encola → responde 202           │      │
                │   └────────────────┬─────────────────────────┘      │
                │                    │ mensaje                        │
                │                    ▼                                │
                │   SQS solicitudes-pendientes ──► (DLQ)              │
                │                    │ event source mapping           │
                │                    ▼                                │
                │   ┌──────────────────────────────────────────┐      │
                │   │ CONTENEDOR Lambda Java 21 (procesamiento)│      │
                │   │ procesa → guarda → notifica              │      │
                │   └────┬───────────────────┬─────────────────┘      │
                │        ▼                   ▼                        │
                │   DynamoDB tabla         SNS "notificaciones"       │
                │   "solicitudes"          ├► email (igual que en la nube)
                │                          └► bandeja simulada (cola)  │
                │                              → se lee con el script │
                │                                avisos.sh            │
                │   CloudWatch: logs de cada ejecución               │
                └────────────────────────────────────────────────────┘
```

**Qué emula cada cosa localmente:**

| En la nube (paso 02) | En el paso 01 (local) |
|---|---|
| Amazon API Gateway | API REST de LocalStack en `localhost:4566` |
| AWS Lambda (Java 21) | Contenedores Docker reales con el runtime `java21` de Lambda |
| Amazon SQS (+ DLQ) | SQS de LocalStack |
| Amazon DynamoDB | DynamoDB de LocalStack |
| Amazon SNS (correo) | SNS de LocalStack → suscripción email (igual que en la nube) **+ una "bandeja" local simulada**: una cola SQS suscrita al tópico donde se leen las notificaciones (`avisos.sh` dentro del contenedor), porque en local no hay SMTP que entregue correos |
| Amazon CloudWatch | CloudWatch de LocalStack (logs de cada Lambda) |
| IAM | No se evalúa permisos en local (usamos credenciales de prueba `test/test`) |

> **Código único, configuración por ambiente:** el mismo Java que usas aquí se despliega tal
> cual en AWS real (paso 02). Las Lambdas detectan el ambiente con la variable
> `AWS_ENDPOINT_URL`: en local apunta a LocalStack; en la nube no existe y el SDK usa AWS real.
> Única diferencia de la copia local: el BOM del AWS SDK pasa de 2.25.70 a 2.29.47 porque el
> soporte de `AWS_ENDPOINT_URL` existe desde la versión 2.28.1 (verificado: con 2.25.70 el
> SDK ignora la variable y la llamada llega al SQS real de AWS). El `pom.xml` original no se tocó.

---

## Prerrequisitos (solo uno)

- **Docker Desktop para Windows** corriendo (usa el backend WSL2 por defecto; no necesitas
  instalar Java, Maven ni AWS CLI: todo corre en contenedores).

Todos los comandos de esta guía son para **PowerShell** (el que abre Docker Desktop
recomendado). También funcionan en CMD, salvo los bucles de espera y el manejo de variables
(`$url`, `$api`), que son de PowerShell.

## Cómo usar la guía

Abre PowerShell y ubícate en la carpeta del paso 01:

```powershell
cd "...\salida\paso01-local"    # ajusta a tu ruta real
docker version                  # confirma que Docker está corriendo
```

### Chuleta: cada operación y su comando de Docker

| Qué quieres hacer | Comando(s) |
|---|---|
| Compilar el Java + pruebas → `out/lambdas.zip` | `docker build` + `docker create` + `docker cp` (Paso 1) |
| Levantar el "AWS local" | `docker compose up -d` (Paso 2) |
| Crear la infraestructura | `docker cp` + `docker exec -e EMAIL_NOTIFICATIONS=... localstack bash /tmp/init-aws.sh` (Paso 3) |
| Prueba de punta a punta | `docker cp` + `docker exec localstack bash /tmp/demo.sh` (Paso 4) |
| Estado del sistema | `docker exec localstack bash /tmp/estado.sh` |
| Ver "el correo" (notificaciones) | `docker exec localstack bash /tmp/avisos.sh` |
| Logs de una Lambda | `docker exec localstack awslocal logs tail ...` |
| URL de la API (para Postman) | `$api = (docker exec localstack awslocal apigateway get-rest-apis --query "items[0].id" --output text)` |
| Apagar y borrar todo | `docker compose down -v` |

### Paso 1 — Compilar el código Java (en Docker, con pruebas incluidas)

```powershell
New-Item -ItemType Directory -Force out | Out-Null
docker build -t solicitudes-builder -f Dockerfile.builder .
docker create --name builder-tmp solicitudes-builder
docker cp builder-tmp:/out/lambdas.zip out/lambdas.zip
docker rm builder-tmp
```

Qué hace: construye una imagen `maven:3.9-eclipse-temurin-21`, compila el proyecto,
**corre las pruebas unitarias** del validador (`mvn package` activa Surefire) y deja
`out/lambdas.zip` (el fat-jar que consumirán las dos Lambdas). Es el equivalente a
`mvn package` + `sam build`, pero sin instalar nada en tu computador. El `docker create`
crea un contenedor detenido solo para copiar el zip con `docker cp` (en Windows no se
puede hacer *pipe* binario de `docker run` hacia `tar` como en Mac/Linux).

Tiempo: ~1-2 min la primera vez (descarga dependencias).

> Si `docker create` dice que `builder-tmp` ya existe: `docker rm -f builder-tmp` y repite.

### Paso 2 — Levantar el "AWS local"

```powershell
docker compose up -d
```

Levanta LocalStack en `http://localhost:4566`. Ese único puerto expone
API Gateway, Lambda, SQS, DynamoDB, SNS y CloudWatch.

Espera a que esté listo (el bucle termina solo cuando responde `200`):

```powershell
do {
  Start-Sleep -Seconds 3
  $ok = try { (Invoke-WebRequest -UseBasicParsing http://localhost:4566/_localstack/health -TimeoutSec 3).StatusCode -eq 200 } catch { $false }
} until ($ok)
Write-Host "LocalStack listo en http://localhost:4566"
```

(Alternativa sin bucle: `docker compose logs -f localstack` y espera el mensaje *Ready*;
sal con `Ctrl+C`.)

### Paso 3 — Crear la infraestructura

```powershell
docker cp out/lambdas.zip localstack:/tmp/lambdas.zip
docker cp scripts/init-aws.sh localstack:/tmp/init-aws.sh
docker exec -e EMAIL_NOTIFICATIONS=tucorreo@duocuc.cl localstack bash /tmp/init-aws.sh
# opcional: cambia tucorreo@duocuc.cl por tu correo institucional
```

Este paso crea **en orden**, igual que haría en la nube:

1. SQS: cola `solicitudes-pendientes` + cola DLQ `solicitudes-dlq` (3 reintentos)
2. DynamoDB: tabla `solicitudes`
3. SNS: tópico `notificaciones` con suscripción email (igual que en la nube) y una
   "bandeja" local simulada (cola `notificaciones-bandeja` suscrita al tópico)
4. Lambda `recepcion` y Lambda `procesamiento` (Java 21, contenedores reales)
5. Event source mapping: SQS activa la Lambda de procesamiento automáticamente
6. API Gateway REST con `POST /solicitudes` integrado por proxy a la Lambda

Al final imprime la URL de la API. También puedes verla cuando quieras:

```powershell
$api = (docker exec localstack awslocal apigateway get-rest-apis --query "items[0].id" --output text)
"http://localhost:4566/restapis/$api/prod/_user_request_/solicitudes"
```

Es idempotente: si ya había infraestructura, la reutiliza (y refresca el código
de las Lambdas con el `out/lambdas.zip` del build más reciente).

### Paso 4 — Probar de punta a punta

```powershell
docker cp scripts/demo.sh localstack:/tmp/demo.sh
docker exec localstack bash /tmp/demo.sh
```

Envía un `POST /solicitudes` válido y **verás la clave del patrón asíncrono**:

1. La respuesta llega **inmediato** con `HTTP 202` y estado `RECIBIDA` — el sistema aceptó
   la solicitud pero todavía **no** la procesó (por eso 202 y no 200).
2. El script queda mirando la tabla DynamoDB hasta que la Lambda de procesamiento
   termina: aparecerá el ítem con `estado: PROCESADA` y el `resultado`.
3. (Opcional si Postman es tu herramienta) usa la URL del Paso 3 con este cuerpo:

```json
{
  "alumno": { "nombre": "María Pérez Soto", "email": "maria.perez@duocuc.cl" },
  "tipo": "CERTIFICADO",
  "descripcion": "Necesito certificado de notas para postular a una beca"
}
```

Otros `tipo` válidos con su `descripcion` (mínimo 10 caracteres):

| `tipo` | `descripcion` de ejemplo |
|---|---|
| `REVISION_NOTAS` | "Solicito revisión de la nota final de Programación Avanzada" |
| `SOPORTE_TECNICO` | "No puedo acceder a mi correo institucional desde ayer" |
| `INFO_ACADEMICA` | "Deseo saber las fechas de inscripción para el próximo semestre" |

**Prueba negativa** (validación: responde `400` y **no** entra a la cola). Se usa el archivo
`ejemplo-invalido.json` incluido en la carpeta para evitar problemas de escape de comillas
en PowerShell:

```powershell
$api = (docker exec localstack awslocal apigateway get-rest-apis --query "items[0].id" --output text)
$url = "http://localhost:4566/restapis/$api/prod/_user_request_/solicitudes"
curl.exe -i -X POST $url -H "Content-Type: application/json" -d "@ejemplo-invalido.json"
```

> Importante: escribe `curl.exe` (no `curl`), porque en PowerShell `curl` es un alias de
> `Invoke-WebRequest` y se comporta distinto.

### Paso 5 — Observar cada servicio (el corazón del aprendizaje)

```powershell
# Estado general: tabla + colas + suscripciones SNS
docker cp scripts/estado.sh localstack:/tmp/estado.sh
docker exec localstack bash /tmp/estado.sh

# Las notificaciones ("el correo")
docker cp scripts/avisos.sh localstack:/tmp/avisos.sh
docker exec localstack bash /tmp/avisos.sh

# Logs CloudWatch de cada Lambda
docker exec localstack awslocal logs tail /aws/lambda/recepcion --since 15m --format short
docker exec localstack awslocal logs tail /aws/lambda/procesamiento --since 15m --format short
```

Qué verificar (misma tabla de verificación que en la nube):

| Dónde | Qué se espera |
|---|---|
| Respuesta del POST | `202` + `solicitudId` + `estado: RECIBIDA` |
| DynamoDB `solicitudes` | ítem con `estado: PROCESADA`, `resultado` y ambas fechas |
| SQS `solicitudes-pendientes` | 0 mensajes pendientes tras procesar |
| SQS `solicitudes-dlq` | siempre vacía (si tiene mensajes, el procesamiento falló 3 veces) |
| SNS (`avisos.sh`) | el "correo": asunto "Solicitud ... procesada" + el cuerpo con el resultado |
| CloudWatch logs | logs de recepción y de procesamiento |

> **Detalle técnico que verás en SQS:** cada vez que lees una cola, los mensajes leídos
> quedan "invisibles" (visibility timeout) por ~30 s. Si justo antes habías visto mensajes
> y ahora no aparecen, no se perdieron: espera 30 s y vuelve a consultar.

## Experimentos para perder el miedo (así se entiende de verdad)

1. **¿Qué pasa si las dos Lambdas "caen"?** Detén LocalStack justo después del POST
   (sin borrar nada): `docker compose stop`. El mensaje **sigue en SQS** y no se pierde.
   Vuelve a levantar con `docker compose start` — ahí queda claro el principio del
   desacoplamiento: la cola retiene el trabajo.
2. **DLQ.** Elimina la Lambda de procesamiento:

   ```powershell
   docker exec localstack awslocal lambda delete-function --function-name procesamiento
   ```

   Envía una solicitud (responde `202` igual: el POST no sabe que el procesador no existe,
   esa es la gracia de la cola) y mira la DLQ con `estado.sh`: tras 3 reintentos el mensaje
   cae a `solicitudes-dlq`. Recrea todo desde cero con:

   ```powershell
   docker compose down -v
   docker compose up -d
   # ... y repite los Pasos 3 y 4
   ```

3. **Picos de tráfico.** Envía 10 POST seguidos (repite el `curl.exe` del Paso 4 en un
   bucle `1..10`): todos responden `202` al instante aunque el procesamiento Java tarde.
   La cola amortigua el pico.

## Estructura del proyecto

```
paso01-local/
├── docker-compose.yml      LocalStack (todo AWS local en un contenedor)
├── Dockerfile.builder      Maven 21 en Docker: compila y corre pruebas
├── README.md               esta guía (comandos directos de Docker, sin make)
├── ejemplo-invalido.json   cuerpo de la prueba negativa (400)
├── java/                   copia del código fuente (no se modifica el original)
├── scripts/
│   ├── init-aws.sh         crea TODA la infraestructura (se ejecuta DENTRO del contenedor)
│   ├── demo.sh             POST de punta a punta + verificación en DynamoDB (idem)
│   ├── estado.sh           estado de tabla, colas, DLQ y suscripciones (idem)
│   └── avisos.sh           lee la bandeja simulada de notificaciones SNS (idem)
└── out/                    (generado) lambdas.zip listo para desplegar
```

> **Nota:** los `.sh` se ejecutan dentro del contenedor LocalStack (Linux), no en tu
> Windows. Por eso se copian con `docker cp` y corren con `docker exec ... bash`.
> No los edites con Bloc de notas: si los guardas con finales de línea CRLF, bash
> falla. Usa VS Code con `LF` si necesitas tocarlos.

## Limpieza

```powershell
# Contenedores huérfanos de Lambda (a veces quedan tras una invocación)
docker ps -aq --filter "name=localstack-lambda" | ForEach-Object { docker rm -f $_ }

# Apaga LocalStack y borra TODO el estado (colas, tabla, logs)
docker compose down -v

# Borra además el zip compilado
Remove-Item -Recurse -Force out
```

La próxima sesión: repite el Paso 1 (si borraste `out/`) + Paso 2 + Paso 3.

## Problemas frecuentes

| Síntoma | Solución |
|---|---|
| `Cannot connect to the Docker daemon` / `error during connect` | Abre Docker Desktop y espera a que el ícono diga "running" antes de cualquier comando |
| LocalStack arranca y muere pidiendo `LOCALSTACK_AUTH_TOKEN` | El compose fija `localstack/localstack:4.5.0` a propósito: las versiones "latest" actuales exigen licencia incluso para arrancar. Quédate en esa versión community |
| El bucle de espera del Paso 2 no termina nunca | Mira `docker compose logs localstack`; si pide auth token o el puerto está ocupado, ver las filas siguientes |
| Puerto 4566 ocupado | Cierra otra instancia de LocalStack o cambia el puerto en `docker-compose.yml` (y en los comandos `localhost:4566` de esta guía) |
| `docker cp` dice que no encuentra `out/lambdas.zip` | Falta compilar: repite el Paso 1 |
| `docker create` dice que `builder-tmp` ya existe | `docker rm -f builder-tmp` y repite el Paso 1 |
| `curl` devuelve un objeto raro de PowerShell | Usaste el alias. Escribe `curl.exe` |
| `bash: /tmp/init-aws.sh: command not found` o `$'\r': command not found` | El script tiene CRLF (se editó en Windows). Vuelve a copiarlo desde la carpeta original o guárdalo con LF |
| La primera invocación de Lambda tarda mucho | Se descarga la imagen `public.ecr.aws/lambda/java:21` y arranca la JVM (cold start de Java). Se ve con `docker ps` |
| La primera prueba del Paso 4 tarda >2 min | Es el **cold start**: la imagen se descarga en el primer POST. Los siguientes procesan en segundos |
| El Paso 3 dice que ya existe | No pasa nada: no re-crea (idempotente). Usa el Paso 4, o re-crea con `docker compose down -v` + `up -d` y repite el Paso 3 |
| No aparece la notificación en `avisos.sh` | Recuerda el visibility timeout: espera 30 s y reintenta. ¿Llegó la publicación? Revisa los logs de procesamiento (línea "SNS enviada") y DynamoDB |
| El ítem no aparece en DynamoDB y la DLQ tiene mensajes | Revisa los logs de procesamiento para ver el error; re-crea con `docker compose down -v` + `up -d` + Paso 3 |

## Mapa con el paso 02 (despliegue real en AWS)

Aquí terminas con `out/lambdas.zip` compilado. En el paso 02:

- el mismo jar se despliega con `sam deploy` (template.yaml del proyecto `solicitudes-serverless`).
- el destino cambia: de LocalStack a tu cuenta AWS Academy (Learner Lab).
- el flujo de verificación (Paso 4 → Paso 5) lo repites con Postman y la consola AWS.

Sugerencia de cierre: compara el `scripts/init-aws.sh` con `template.yaml`: **declaran la misma
arquitectura**, uno con comandos y otro con infraestructura como código.
