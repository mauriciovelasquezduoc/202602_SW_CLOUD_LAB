# README-ejecutar.md — Ejecutar el sistema paso a paso

**Curso:** JAVA — Diseño y Construcción de Soluciones Nativas en Nube
**Alcance:** correr el sistema de solicitudes en tu computador (paso 01) y saltar a AWS real (paso 02).

Este documento es la **guía de ejecución**: cada comando, **qué hace por dentro**, **qué se
espera ver** y **qué hacer si falla**, con las tres variantes de terminal en paralelo:

| Tu sistema | Terminal que usarás | Los 6 comandos viven en |
|---|---|---|
| Windows (PowerShell) | PowerShell | `scripts\*.ps1` |
| Windows (CMD) | Símbolo del sistema | `scripts\*.bat` |
| macOS / Linux | Terminal (bash) | `bin/*.sh` |

Los comandos `docker` y `docker compose` son **idénticos en las tres terminales**; solo cambia
el wrapper de cada operación. Elaborado sobre `paso01-local/` (el AWS local en Docker).

> Si algo de la teoría no te suena, los documentos de fondo son `README.md` (el viaje completo:
> tradicional → problema → asíncrona) y `documento-diseno.md` (decisiones formales). Aquí solo
> se ejecuta.

---

## Paso 0 — Verificar que Docker está corriendo

**Qué hace:** `docker version` pregunta al daemon de Docker si está vivo; es el chequeo de
"¿está todo instalado?" antes de empezar.

```powershell
# PowerShell
docker version
```

```bat
:: CMD
docker version
```

```bash
# macOS / Linux
docker version
```

**Qué se espera:** un bloque `Client` y un bloque `Server` con números de versión
(p. ej. `Server: Docker Desktop 4.x` o `Engine: 27.x`).

**Si falla:** `Cannot connect to the Docker daemon` (o en Windows `error during connect`)
significa que el motor no arrancó: abre **Docker Desktop** y espera a que el ícono diga
*running* (en Linux, `sudo systemctl start docker`). En Linux, si sale *permission denied*,
tu usuario no está en el grupo `docker`: usa `sudo` delante de cada `docker` o pide que te
agreguen al grupo.

---

## Paso 1 — Levantar el "AWS local"

**Qué hace:** `docker compose up -d` lee `docker-compose.yml` y arranca **LocalStack**
(`localstack/localstack:4.5.0`, versión fija community) en segundo plano (`-d` = detached).
Ese único contenedor expone en el puerto `4566` los servicios que en la nube son de AWS:
API Gateway, Lambda, SQS, DynamoDB, SNS y CloudWatch. LocalStack tiene permiso para hablar
con el socket de Docker porque, al invocar una Lambda Java, crea **contenedores reales**
con el runtime `java21` de Lambda y los borra al terminar.

```powershell
# PowerShell
docker compose up -d
```

```bat
:: CMD
docker compose up -d
```

```bash
# macOS / Linux
docker compose up -d
```

**Qué se espera:** `Container localstack  Started` (o *Running* si ya estaba).

Después, **espera a que LocalStack esté listo** — el bucle consulta su endpoint de salud
hasta que responde:

```powershell
# PowerShell
do {
  Start-Sleep -Seconds 3
  $ok = try { (Invoke-WebRequest -UseBasicParsing http://localhost:4566/_localstack/health -TimeoutSec 3).StatusCode -eq 200 } catch { $false }
} until ($ok)
Write-Host "LocalStack listo en http://localhost:4566"
```

```bash
# macOS / Linux
until curl -sf http://localhost:4566/_localstack/health > /dev/null; do sleep 3; done
echo "LocalStack listo en http://localhost:4566"
```

(CMD no tiene bucle cómodo: ejecuta una vez `docker exec localstack curl -s http://localhost:4566/_localstack/health`
cada 10 s hasta ver `"status": "OK"`.)

**Qué se espera:** el mensaje *LocalStack listo* en ~5-15 segundos.

**Si falla:** LocalStack arranca y muere pidiendo `LOCALSTACK_AUTH_TOKEN` → el compose fija
la versión 4.5.0 a propósito (las `latest` actuales exigen licencia); no la cambies.
Puerto 4566 ocupado → cierra otra instancia o cambia el puerto en `docker-compose.yml`.

---

## Paso 2 — Compilar el código Java (sin instalar Java)

**Qué hace el wrapper:** construye una imagen con **Maven 3.9 + JDK 21** (`Dockerfile.builder`),
compila el proyecto, **corre las pruebas unitarias** del validador (Surefire, `mvn package`)
y copia el resultado — el *fat-jar* empaquetado como `lambdas.zip` — a `out/lambdas.zip`.
Es el equivalente a `mvn package` + `sam build`, sin instalar nada en tu computador.

```powershell
# PowerShell
.\scripts\build.ps1
```

```bat
:: CMD
scripts\build.bat
```

```bash
# macOS / Linux
./bin/build.sh
```

**Qué se espera:** el log de Maven terminando en `BUILD SUCCESS`, y al final:
`OK -> out\lambdas.zip listo.` — **1-2 min la primera vez** (descarga dependencias);
las siguientes son segundos por la caché de Docker.

**Si falla:** `Fallo el build de la imagen` → revisa el error de Maven arriba (casi siempre
es red o un test unitario rojo; los tests se ven en el log con `Tests run: ...`).
Si el wrapper dice que falta algo, confirma que estás dentro de la carpeta `paso01-local`.

---

## Paso 3 — Crear la infraestructura

**Qué hace:** copia `out/lambdas.zip` y `scripts/init-aws.sh` al contenedor y los ejecuta
**dentro** de LocalStack con `awslocal` (el AWS CLI de LocalStack). Crea, **en el mismo
orden en que lo declararía el template SAM del paso 02**:

1. **SQS**: cola `solicitudes-pendientes` + DLQ `solicitudes-dlq` (redrive a los 3 intentos).
2. **DynamoDB**: tabla `solicitudes` (PK `solicitudId`).
3. **SNS**: tópico `notificaciones` con la suscripción email (igual que en la nube) **+
   la "bandeja" local**: una cola `notificaciones-bandeja` suscrita al tópico, porque en
   local no hay SMTP que entregue correos.
4. **Lambdas Java 21**: `recepcion` y `procesamiento` (120 s de timeout, 1024 MB).
5. **Event source mapping**: SQS despierta sola a la Lambda de procesamiento (lotes de 5).
6. **API Gateway REST** con `POST /solicitudes` integrado por proxy a la Lambda de recepción.

```powershell
# PowerShell
.\scripts\init-aws.ps1 -Email tucorreo@duocuc.cl
```

```bat
:: CMD
scripts\init-aws.bat tucorreo@duocuc.cl
```

```bash
# macOS / Linux
./bin/init-aws.sh tucorreo@duocuc.cl
```

**Qué se espera:** las secciones `== 1. SQS ==` a `== 6. API Gateway ==`, y al final:

```
 Infraestructura local lista. Registra una solicitud con: ...
 URL de la API:
   http://localhost:4566/restapis/<api-id>/prod/_user_request_/solicitudes
```

**Es idempotente**: si la infraestructura ya existía, la reutiliza y solo actualiza el código
de las Lambdas con el build más reciente (lo verás como `== 0. Estado previo ==`).

**Si falla:** `Falta out/lambdas.zip` → vuelve al Paso 2. `LocalStack no está corriendo` →
vuelve al Paso 1.

---

## Paso 4 — Probar de punta a punta (la lección del sistema)

**Qué hace:** envía un `POST /solicitudes` **válido** desde dentro del contenedor y queda
mirando la tabla de DynamoDB hasta que la Lambda de procesamiento termina.

```powershell
# PowerShell
.\scripts\demo.ps1
```

```bat
:: CMD
scripts\demo.bat
```

```bash
# macOS / Linux
./bin/demo.sh
```

**Qué se espera — y es la lección central del patrón asíncrono — en dos actos:**

1. La respuesta llega **inmediata**:

```json
Respuesta del sistema (HTTP 202 Accepted, aún NO procesada):
{"solicitudId":"b3f8c2a1-...","estado":"RECIBIDA","mensaje":"Su solicitud fue recibida..."}
```

   `202`, y no `200`: el sistema **aceptó** la solicitud pero todavía **no** la procesó.
   El POST no espera el procesamiento — eso es RF3.
2. El script queda esperando (puntos suspensivos) hasta que aparece la tabla de DynamoDB
   con el ítem `PROCESADA`, su `resultado` y `fechaProcesamiento`. La primera vez tarda
   **~1 min**: es el *cold start* (Docker descarga la imagen `lambda/java:21` y arranca la
   JVM). Las siguientes son segundos.

### Prueba manual (Postman o curl) — opcional

Obtén la URL (queda impresa al final del Paso 3; o recupérala):

```powershell
# PowerShell
$api = (docker exec localstack awslocal apigateway get-rest-apis --query "items[0].id" --output text)
$url = "http://localhost:4566/restapis/$api/prod/_user_request_/solicitudes"
curl.exe -i -X POST $url -H "Content-Type: application/json" -d "@ejemplo-valido.json"
```

```bash
# macOS / Linux
api=$(docker exec localstack awslocal apigateway get-rest-apis --query "items[0].id" --output text)
url="http://localhost:4566/restapis/$api/prod/_user_request_/solicitudes"
curl -i -X POST "$url" -H "Content-Type: application/json" -d @ejemplo-valido.json
```

```bat
:: CMD
docker exec localstack awslocal apigateway get-rest-apis --query "items[0].id" --output text
:: copia el id a mano y ejecuta:
curl.exe -i -X POST "http://localhost:4566/restapis/<api-id>/prod/_user_request_/solicitudes" -H "Content-Type: application/json" -d "@ejemplo-valido.json"
```

- En Windows usa **`curl.exe`**, nunca `curl` (en PowerShell es un alias de
  `Invoke-WebRequest` que se comporta distinto).
- El cuerpo válido está en `ejemplo-valido.json`; otros `tipo` válidos:
  `REVISION_NOTAS`, `SOPORTE_TECNICO`, `INFO_ACADEMICA` (descripción mínima 10 caracteres).

### Montarlo en Postman (30 segundos, sin escribir nada a mano)

Postman puede **importar un comando curl tal cual** y convertirlo en request. Reemplaza
`<api-id>` por el id que imprime el Paso 3 (o el de arriba) y pega esto en Postman:

```bash
curl --location --request POST 'http://localhost:4566/restapis/<api-id>/prod/_user_request_/solicitudes' \
  --header 'Content-Type: application/json' \
  --data-raw '{
    "alumno": { "nombre": "María Pérez Soto", "email": "maria.perez@duocuc.cl" },
    "tipo": "CERTIFICADO",
    "descripcion": "Necesito certificado de notas para postular a una beca"
  }'
```

Pasos: **Import → Raw text → pega el curl → Import**. Postman crea el `POST` con el header
y el body ya cargados. Guárdalo en una colección (ej. *Solicitudes DUOC*) y:

1. **Duplica el request** y cambia `tipo` para probar los 4 tipos (`CERTIFICADO`,
   `REVISION_NOTAS`, `SOPORTE_TECNICO`, `INFO_ACADEMICA`) — cada uno responde `202` y en
   `avisos` verás su `resultado` distinto.
2. **Crea una variante inválida** (nombre "Ana", email "no-valido", tipo "PRESTAMO_LIBROS")
   — debe responder `400` con el detalle. Así tienes la prueba positiva y negativa del RF2
   en la colección.
3. **Tests automáticos en Postman** (pestaña *Tests* del request): 
   `pm.test("aceptada para procesar", () => pm.response.to.have.status(202));` — la colección
   queda lista para correr con *Run collection*.

### ¿Y el correo? Local es simulado; en la nube llega de verdad

| Dónde | Qué pasa con el "correo" |
|---|---|
| **Paso 01 (local)** | LocalStack community **no envía email real** (no hay SMTP). La suscripción email que creó `init-aws` queda "pendiente de confirmación" para siempre: es normal. El correo **se simula**: SNS entrega a la cola `notificaciones-bandeja` y se lee con `avisos` (`./bin/avisos.sh` · `scripts\avisos.ps1` · `scripts\avisos.bat`). Mismo contenido que el email real |
| **Paso 02 (nube real)** | SNS **sí envía el correo de verdad** a la casilla que declaraste en `sam deploy`. Único requisito: **confirmar la suscripción** — llega un mail "AWS Notification - Subscription Confirmation" y hay que hacer clic en *Confirm subscription*. Sin ese clic, no llega NINGÚN correo (causa #1 de "no me llegó el email" en el lab) |

En la demo de clase: en local muestra `avisos` (el correo del lab), y en la nube el buzón
real del alumno. Mismo flujo SNS, dos entregas.

### Prueba negativa (RF2)

```powershell
curl.exe -i -X POST $url -H "Content-Type: application/json" -d "@ejemplo-invalido.json"
```

```bash
curl -i -X POST "$url" -H "Content-Type: application/json" -d @ejemplo-invalido.json
```

**Qué se espera:** `HTTP 400 Bad Request` con el **detalle de cada error** (nombre corto,
email inválido, tipo desconocido, descripción corta) — y **nada más**: no hay correo, no
hay ítem en DynamoDB, no hay mensaje en cola. La validación en la recepción evita que la
basura entre al sistema.

---

## Paso 5 — Observar cada servicio (el corazón del aprendizaje)

**`estado`** muestra el estado vivo: tabla DynamoDB, mensajes pendientes (y en la DLQ) y
suscripciones SNS. **`avisos`** lee la bandeja simulada — *el "correo" que en la nube real
sí llega por email*.

```powershell
# PowerShell
.\scripts\estado.ps1
.\scripts\avisos.ps1
```

```bat
:: CMD
scripts\estado.bat
scripts\avisos.bat
```

```bash
# macOS / Linux
./bin/estado.sh
./bin/avisos.sh
```

**Qué se espera en `estado`:** la tabla de solicitudes con `estado: PROCESADA`; las colas
con `ApproximateNumberOfMessages: 0` (pendientes) y DLQ vacía; las 2 suscripciones SNS.

**Qué se espera en `avisos`:** el sobre SNS parseado:

```
Asunto: Solicitud b3f8c2a1 procesada
Hola María Pérez Soto: Tu solicitud de tipo CERTIFICADO fue PROCESADA con éxito...
```

**Ojo con el *visibility timeout*:** SQS hace "invisible" cada mensaje ~30 s después de
leerlo. Si `avisos` dice *bandeja vacía* justo después de procesar, espera 30 s y reintenta.

**Logs de CloudWatch** — con el wrapper `logs` (sin argumento muestra las dos Lambdas;
acepta `recepcion` o `procesamiento`):

```bash
# macOS / Linux
./bin/logs.sh                 # las dos
./bin/logs.sh recepcion       # solo recepción
```

```powershell
# PowerShell
.\scripts\logs.ps1 recepcion   # o sin argumento: las dos
```

```bat
:: CMD
scripts\logs.bat recepcion     :: o sin argumento: las dos
```

Por dentro, el wrapper ejecuta la API real `filter-log-events` — ojo, `awslocal` usa el
motor del CLI v1 y **no soporta `logs tail`** (eso es azúcar del AWS CLI v2):

```bash
docker exec localstack awslocal logs filter-log-events \
  --log-group-name /aws/lambda/recepcion \
  --query 'events[].message' --output text
```

**Qué se espera:** por cada invocación, un `START RequestId: ...`, el log del handler
(p. ej. `Solicitud ... encolada en SQS` o `Procesando solicitud ...`) y un
`REPORT RequestId: ... Duration: ...` con el tiempo y memoria consumida.

### Checklist de verificación (igual en local y en la nube)

| Dónde | Qué se espera |
|---|---|
| Respuesta del POST | `202` + `solicitudId` + `estado: RECIBIDA` |
| DynamoDB `solicitudes` | ítem con `estado: PROCESADA`, `resultado` y ambas fechas |
| SQS `solicitudes-pendientes` | 0 mensajes pendientes tras procesar |
| SQS `solicitudes-dlq` | siempre vacía (mensajes aquí = 3 fallos del procesamiento) |
| `avisos` / correo | asunto "Solicitud ... procesada" + resultado |
| CloudWatch logs | logs de recepción y de procesamiento |

---

## Paso 6 — Experimentos para entender de verdad

### 6.1 Picos de tráfico: la cola amortigua

Envía N POST seguidos (10 por defecto) y muestra el **código HTTP real** de cada uno:
todos responden `202` **al instante** aunque el procesamiento Java tarde. Esa es la gracia:
la recepción no sufre lo que sufre el procesamiento. Al final muestra el estado de la cola,
por si alcanzas a ver los mensajes en vuelo.

```powershell
# PowerShell
.\scripts\picos.ps1          # 10 solicitudes
.\scripts\picos.ps1 50       # 50 solicitudes
```

```bat
:: CMD
scripts\picos.bat
scripts\picos.bat 50
```

```bash
# macOS / Linux
./bin/picos.sh
./bin/picos.sh 50
```

**Qué se espera:** N líneas `solicitud i -> HTTP 202`, y al final la cola. Si corres
`estado` justo después (o el pico es grande), verás mensajes acumados en `pendientes`
drenándose a 0; si la Lambda está tibia, quizá solo veas `NotVisible` en 5: son los
mensajes **en vuelo** (invisibles por el visibility timeout mientras se procesan).

**Por dentro**, cada envío es la API real contra el endpoint resuelto con `docker exec`:

```bash
api=$(docker exec localstack awslocal apigateway get-rest-apis --query "items[0].id" --output text)
url="http://localhost:4566/restapis/$api/prod/_user_request_/solicitudes"

for i in $(seq 1 10); do
  code=$(curl -s -o /dev/null -w "%{http_code}" -X POST "$url" -H "Content-Type: application/json" -d @ejemplo-valido.json)
  echo "solicitud $i -> HTTP $code"
done
```

> Ejecuta los wrappers desde cualquier carpeta: se ubican solos. El `ejemplo-valido.json`
> debe existir en `paso01-local/` (viene con el repo).

### 6.2 Apagón: la cola retiene el trabajo

Detén LocalStack justo después de un POST **sin borrar nada** y vuelve a levantar:

```bash
docker compose stop     # en las tres terminales
docker compose start
```

**Qué se espera:** el mensaje **sigue en SQS** y el procesamiento termina cuando el sistema
vuelve. Ese es el principio del desacoplamiento: la cola retiene el trabajo aunque el
procesador muera.

### 6.3 DLQ: qué pasa cuando el procesamiento falla 3 veces

Elimina la Lambda de procesamiento, envía una solicitud y observa la DLQ:

```bash
docker exec localstack awslocal lambda delete-function --function-name procesamiento
# luego: demo (responde 202 igual — el POST no sabe que el procesador no existe)
./bin/estado.sh    # o scripts\estado.ps1 / scripts\estado.bat
```

**Qué se espera:** tras 3 reintentos fallidos, el mensaje cae en `solicitudes-dlq` (auditable,
sin bloquear la cola). Recrea todo: `docker compose down -v` + `up -d` + Pasos 2-3.

---

## Paso 7 — Apagar y limpiar

**Qué hace:** borra los contenedores huérfanos de Lambda (a veces quedan tras una
invocación), apaga LocalStack y borra **todo el estado** (colas, tabla, logs) con `-v`
(volúmenes).

```powershell
# PowerShell
.\scripts\limpiar.ps1
Remove-Item -Recurse -Force out   # (opcional) borra también el zip compilado
```

```bat
:: CMD
scripts\limpiar.bat
rmdir /s /q out                   :: (opcional)
```

```bash
# macOS / Linux
./bin/limpiar.sh
rm -rf out                        # (opcional)
```

**Qué se espera:** `OK - Todo limpio`. La próxima sesión: Paso 0 → 1 → 2 → 3 (todo se
recrea en minutos; los datos de prueba no se conservan).

---

## Paso 8 — El salto a la nube (paso 02, AWS Academy)

**Aquí el sistema operativo deja de importar:** el despliegue real se hace desde **Cloud9
del Learner Lab, en el navegador** (una terminal Linux ya configurada en AWS), así que da
igual si estás en Windows, Mac o Linux.

1. Entra al lab → Cloud9 → sube (o clona) el proyecto `solicitudes-serverless`.
2. `sam build` → compila y corre las pruebas (misma lógica que `build.ps1`).
3. `sam deploy --guided` → crea TODA la infraestructura declarada en `template.yaml`
   (los mismos componentes del Paso 3, pero como infraestructura como código y reales).
   Región obligatoria: `us-east-1` o `us-west-2`. Las Lambdas usan el rol `LabRole` del lab.
4. **Confirma la suscripción SNS** en tu correo ("AWS Notification - Subscription
   Confirmation") — sin esto no llegan las notificaciones.
5. Repite el Paso 4 y el Paso 5 contra la `ApiUrl` de los Outputs: ahora el `avisos`
   es tu **bandeja de correo real**, y la verificación de DynamoDB/SQS se hace en la
   **consola AWS**.
6. Al terminar la sesión: `sam delete` (el presupuesto del lab es limitado).

El paralelo que cierra el círculo pedagógico: compara `scripts/init-aws.sh` (los mismos
pasos, con comandos) contra `template.yaml` (los mismos pasos, como infraestructura como
código). **Declaran la misma arquitectura.**

---

## Problemas frecuentes

| Síntoma | Sistema | Solución |
|---|---|---|
| `Cannot connect to the Docker daemon` | todas | Abre Docker Desktop / `sudo systemctl start docker` y espera el *running* |
| *permission denied* en `docker` | Linux | Tu usuario no está en el grupo `docker`: usa `sudo` |
| `running scripts is disabled` | PowerShell | `Set-ExecutionPolicy -Scope Process Bypass` (CMD y mac/linux no tienen esta restricción) |
| LocalStack pide `LOCALSTACK_AUTH_TOKEN` | todas | El compose fija la versión 4.5.0 community a propósito; no la cambies |
| Puerto 4566 ocupado | todas | Cierra otra instancia o cambia el puerto en `docker-compose.yml` |
| `Falta out/lambdas.zip` | todas | Falta el Paso 2 (`build`) |
| `curl` devuelve un objeto raro | PowerShell | Usaste el alias: escribe `curl.exe` |
| `$'\r': command not found` dentro del contenedor | Windows | Un `.sh` quedó con CRLF: vuelve a copiarlo del repo (`.gitattributes` fuerza LF) |
| Primera invocación tarda ~1 min | todas | Cold start de Java: se descarga la imagen `lambda/java:21` |
| `avisos` dice "bandeja vacía" | todas | Visibility timeout de 30 s: espera y reintenta |
| Ítem no aparece y la DLQ tiene mensajes | todas | El procesamiento falló 3 veces: mira los logs de `procesamiento` |
| `aws: error: Invalid choice, valid choices are...` al pedir logs | todas | `awslocal` (CLI v1) no tiene `logs tail` (azúcar del CLI v2): usa el wrapper `logs` de tu sistema (Paso 5) o `logs filter-log-events` |
| `The security token ... expired` (paso 02) | AWS | Credenciales del lab expiradas: re-exportar o usar Cloud9 |

---

*Materiales de fondo: `README.md` (el viaje completo y el porqué de cada decisión),
`paso01-local/README.md` (la guía detallada local), `solicitudes-serverless/README.md`
(despliegue en la nube) y `documento-diseno.md` (decisiones formales).*
