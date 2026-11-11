# PASO 01 · Guía: correr TODO el sistema local en Docker (Windows, macOS y Linux — sin `make`)

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
                │                                avisos (ps1/bat/sh)  │
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
| Amazon SNS (correo) | SNS de LocalStack → suscripción email (igual que en la nube) **+ una "bandeja" local simulada**: una cola SQS suscrita al tópico donde se leen las notificaciones (`avisos` en cualquiera de las 3 variantes: `bin/avisos.sh` en mac/linux, `scripts\avisos.ps1` o `scripts\avisos.bat` en Windows), porque en local no hay SMTP que entregue correos |
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

- **Docker** corriendo: **Docker Desktop** (Windows o macOS) o **Docker Engine** (Linux;
  si tu usuario no está en el grupo `docker`, antepón `sudo` a los comandos `docker`).
  No necesitas instalar Java, Maven ni AWS CLI: todo corre en contenedores.

La guía muestra los comandos en **PowerShell** y en **CMD**; cada paso indica también su
equivalente para **macOS/Linux** (`./bin/*.sh`). Los comandos `docker` y `docker compose`
son idénticos en las tres terminales; solo cambia el wrapper de cada operación.

## Cómo usar la guía

Abre PowerShell, CMD o tu terminal (macOS/Linux) y ubícate en la carpeta del paso 01:

```powershell
cd "...\salida\paso01-local"    # ajusta a tu ruta real (mac/linux: cd ~/ruta/paso01-local)
docker version                  # confirma que Docker está corriendo
```

La guía muestra los comandos en PowerShell; si usas **CMD**, cada paso indica su
equivalente `scripts\*.bat`, y si usas **macOS/Linux**, su equivalente `./bin/*.sh`
(los `.sh` de `bin/` vienen con permiso de ejecución; si un checkout los pierde:
`chmod +x bin/*.sh`, o ejecútalos con `bash bin/demo.sh`).

### Chuleta: cada operación y su comando

Todos los pasos existen en tres sabores paralelos: **`.ps1`** (PowerShell), **`.bat`** (CMD)
y **`.sh`** (macOS/Linux, en `bin/`). Elige según tu terminal; los tres hacen exactamente lo mismo.

| Qué quieres hacer | PowerShell | CMD | macOS / Linux |
|---|---|---|---|
| Compilar el Java + pruebas → `out/lambdas.zip` | `.\scripts\build.ps1` | `scripts\build.bat` | `./bin/build.sh` |
| Levantar el "AWS local" | `docker compose up -d` | `docker compose up -d` | `docker compose up -d` |
| Crear la infraestructura | `.\scripts\init-aws.ps1 -Email tucorreo@duocuc.cl` | `scripts\init-aws.bat tucorreo@duocuc.cl` | `./bin/init-aws.sh tucorreo@duocuc.cl` |
| Prueba de punta a punta | `.\scripts\demo.ps1` | `scripts\demo.bat` | `./bin/demo.sh` |
| Estado del sistema | `.\scripts\estado.ps1` | `scripts\estado.bat` | `./bin/estado.sh` |
| Ver "el correo" (notificaciones) | `.\scripts\avisos.ps1` | `scripts\avisos.bat` | `./bin/avisos.sh` |
| Logs de una Lambda | `docker exec localstack awslocal logs filter-log-events --log-group-name /aws/lambda/recepcion --query 'events[].message' --output text` | igual | igual |
| URL de la API (para Postman) | `$api = (docker exec localstack awslocal apigateway get-rest-apis --query "items[0].id" --output text)` | `docker exec localstack awslocal apigateway get-rest-apis --query "items[0].id" --output text` | `docker exec localstack awslocal apigateway get-rest-apis --query "items[0].id" --output text` |
| Apagar y borrar todo | `.\scripts\limpiar.ps1` | `scripts\limpiar.bat` | `./bin/limpiar.sh` |

> **¿PowerShell bloquea los scripts?** Si sale *"running scripts is disabled"*: ejecuta una vez
> `Set-ExecutionPolicy -Scope Process Bypass` en esa ventana de PowerShell y reintenta.
> **CMD no tiene esa restricción**: los `.bat` corren sin configurar nada.

### Paso 1 — Compilar el código Java (en Docker, con pruebas incluidas)

```powershell
.\scripts\build.ps1
```

En CMD: `scripts\build.bat` · En macOS/Linux: `./bin/build.sh`

Qué hace por dentro (puedes verlo en `scripts\build.ps1`): construye una imagen
`maven:3.9-eclipse-temurin-21`, compila el proyecto, **corre las pruebas unitarias** del
validador (`mvn package` activa Surefire) y deja `out/lambdas.zip` (el fat-jar que consumirán
las dos Lambdas). Es el equivalente a `mvn package` + `sam build`, pero sin instalar nada en
tu computador. El `docker create` crea un contenedor detenido solo para copiar el zip con
`docker cp` (en Windows no se puede hacer *pipe* binario de `docker run` hacia `tar` como en
Mac/Linux).

Tiempo: ~1-2 min la primera vez (descarga dependencias).

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

En macOS/Linux:

```bash
until curl -sf http://localhost:4566/_localstack/health > /dev/null; do sleep 3; done
echo "LocalStack listo en http://localhost:4566"
```

(Alternativa sin bucle: `docker compose logs -f localstack` y espera el mensaje *Ready*;
sal con `Ctrl+C`.)

### Paso 3 — Crear la infraestructura

```powershell
.\scripts\init-aws.ps1 -Email tucorreo@duocuc.cl
# opcional: cambia tucorreo@duocuc.cl por tu correo institucional
```

En CMD: `scripts\init-aws.bat tucorreo@duocuc.cl` · En macOS/Linux: `./bin/init-aws.sh tucorreo@duocuc.cl`

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
.\scripts\demo.ps1
```

En CMD: `scripts\demo.bat` · En macOS/Linux: `./bin/demo.sh`

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
.\scripts\estado.ps1

# Las notificaciones ("el correo")
.\scripts\avisos.ps1

# Logs CloudWatch de cada Lambda.
# OJO: awslocal usa el motor del CLI v1 y NO soporta "logs tail" (eso es azúcar
# del CLI v2): se usa la API real filter-log-events.
docker exec localstack awslocal logs filter-log-events --log-group-name /aws/lambda/recepcion --query 'events[].message' --output text
docker exec localstack awslocal logs filter-log-events --log-group-name /aws/lambda/procesamiento --query 'events[].message' --output text
```

En CMD: `scripts\estado.bat` y `scripts\avisos.bat` · En macOS/Linux: `./bin/estado.sh` y `./bin/avisos.sh` (los logs con `docker exec` son iguales).

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

3. **Picos de tráfico.** Envía 10 POST seguidos con el cuerpo válido: todos responden `202`
   al instante aunque el procesamiento Java tarde. La cola amortigua el pico.

   ```powershell
   # $url es la del Paso 4 (la crea .\scripts\init-aws.ps1 al final, o defínela:
   $api = (docker exec localstack awslocal apigateway get-rest-apis --query "items[0].id" --output text)
   $url = "http://localhost:4566/restapis/$api/prod/_user_request_/solicitudes"

   1..10 | ForEach-Object {
     curl.exe -s -X POST $url -H "Content-Type: application/json" -d "@ejemplo-valido.json" | Out-Null
     "solicitud $_ -> 202 Accepted"
   }
   ```

   En macOS/Linux:

   ```bash
   for i in $(seq 1 10); do
     curl -s -X POST "$url" -H "Content-Type: application/json" -d @ejemplo-valido.json > /dev/null
     echo "solicitud $i -> 202 Accepted"
   done
   ```

## Estructura del proyecto

```
paso01-local/
├── docker-compose.yml      LocalStack (todo AWS local en un contenedor)
├── Dockerfile.builder      Maven 21 en Docker: compila y corre pruebas
├── README.md               esta guía (PowerShell nativo, sin make)
├── ejemplo-valido.json     cuerpo válido para POST manuales (curl.exe o Postman)
├── ejemplo-invalido.json   cuerpo de la prueba negativa (400)
├── java/                   copia del código fuente (no se modifica el original)
├── scripts/
│   ├── build.ps1           PASO 1: compila el Java en Docker → out/lambdas.zip
│   ├── init-aws.ps1        PASO 3: crea toda la infraestructura (-Email tucorreo)
│   ├── demo.ps1            PASO 4: prueba de punta a punta (POST + verificación)
│   ├── estado.ps1          PASO 5: estado de tabla, colas, DLQ y suscripciones
│   ├── avisos.ps1          PASO 5: lee la bandeja simulada de notificaciones
│   ├── limpiar.ps1         limpieza: borra contenedores, apaga y borra el estado
│   ├── build.bat           los MISMOS seis pasos en versión CMD (sin PowerShell)
│   ├── init-aws.bat
│   ├── demo.bat
│   ├── estado.bat
│   ├── avisos.bat
│   ├── limpiar.bat
│   └── *.sh                la lógica que ejecutan los .ps1/.bat (DENTRO del contenedor)
├── bin/
│   ├── build.sh            los MISMOS seis pasos para macOS/Linux (bash)
│   ├── init-aws.sh
│   ├── demo.sh
│   ├── estado.sh
│   ├── avisos.sh
│   └── limpiar.sh
└── out/                    (generado) lambdas.zip listo para desplegar
```

> **Nota:** tú solo usas los wrappers de tu sistema: `.ps1` (PowerShell) o `.bat` (CMD) en
> Windows, `bin/*.sh` en macOS/Linux. Los `.sh` de `scripts/` son la lógica que esos wrappers
> copian y ejecutan DENTRO del contenedor LocalStack (Linux), donde `awslocal` y `bash` sí
> existen. No los edites con Bloc de notas: si quedan con finales de línea CRLF, bash falla.
> El archivo `.gitattributes` del repo fuerza `LF` para los `.sh` en cualquier checkout;
> usa VS Code con `LF` si necesitas tocarlos a mano.

## Limpieza

```powershell
.\scripts\limpiar.ps1             # huerfanos de Lambda + docker compose down -v
Remove-Item -Recurse -Force out   # (opcional) borra también el zip compilado
```

En CMD: `scripts\limpiar.bat` y `rmdir /s /q out` (opcional) · En macOS/Linux: `./bin/limpiar.sh` y `rm -rf out` (opcional).

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
