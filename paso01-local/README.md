# PASO 01 · Guía: correr TODO el sistema local en Docker

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
                │                              → se lee con make avisos
                │                                                    │
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
| Amazon SNS (correo) | SNS de LocalStack → suscripción email (igual que en la nube) **+ una "bandeja" local simulada**: una cola SQS suscrita al tópico donde se leen las notificaciones (`make avisos`), porque en local no hay SMTP que entregue correos |
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

- **Docker** corriendo (Docker Desktop o colima). No necesitas instalar Java, Maven ni AWS CLI: todo corre en contenedores.

## Cómo usar la guía

```bash
cd salida/paso01-local
make help        # ve todos los comandos disponibles
```

### Paso 1 — Compilar el código Java (en Docker, con pruebas incluidas)

```bash
make build
```

Qué hace: levanta un contenedor `maven:3.9-eclipse-temurin-21`, compila el proyecto,
**corre las pruebas unitarias** del validador y produce `out/lambdas.zip` (el fat-jar
que consumirán las dos Lambdas). Es el mismo equivalente a `mvn package` + `sam build`,
pero sin instalar nada en tu computador.

Tiempo: ~1-2 min la primera vez (descarga dependencias).

### Paso 2 — Levantar el "AWS local"

```bash
make up
```

Levanta LocalStack en `http://localhost:4566`. Ese único puerto expone
API Gateway, Lambda, SQS, DynamoDB, SNS y CloudWatch.

### Paso 3 — Crear la infraestructura

```bash
make init                # (opcional) make init EMAIL=tucorreo@duocuc.cl
```

Este comando crea **en orden**, igual que haría en la nube:

1. SQS: cola `solicitudes-pendientes` + cola DLQ `solicitudes-dlq` (3 reintentos) 
2. DynamoDB: tabla `solicitudes`
3. SNS: tópico `notificaciones` con suscripción email (igual que en la nube) y una
   "bandeja" local simulada (cola `notificaciones-bandeja` suscrita al tópico)
4. Lambda `recepcion` y Lambda `procesamiento` (Java 21, contenedores reales)
5. Event source mapping: SQS activa la Lambda de procesamiento automáticamente
6. API Gateway REST con `POST /solicitudes` integrado por proxy a la Lambda

Al final imprime la URL de la API. También puedes verla con `make url`.
Es idempotente: si ya había infraestructura, la reutiliza (y refresca el código
de las Lambdas con el `out/lambdas.zip` del build más reciente).

### Paso 4 — Probar de punta a punta

```bash
make demo
```

Envía un `POST /solicitudes` válido y **verás la clave del patrón asíncrono**:

1. La respuesta llega **inmediato** con `HTTP 202` y estado `RECIBIDA` — el sistema aceptó
   la solicitud pero todavía **no** la procesó (por eso 202 y no 200).
2. El script queda mirando la tabla DynamoDB hasta que la Lambda de procesamiento
   termina: aparecerá el ítem con `estado: PROCESADA` y el `resultado`.
3. (Opcional si Postman es tu herramienta) usa la URL de `make url` con este cuerpo:

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

**Prueba negativa** (validación: responde `400` y **no** entra a la cola):

```bash
curl -i -X POST "$(make url)" -H "Content-Type: application/json" \
  -d '{ "alumno": { "nombre": "Ana", "email": "no-valido" }, "tipo": "PRESTAMO_LIBROS", "descripcion": "corta" }'
```

### Paso 5 — Observar cada servicio (el corazón del aprendizaje)

```bash
make estado                             # tabla + colas + suscripciones SNS
make logs-recepcion                     # logs CloudWatch de la Lambda 1
make logs-procesamiento                 # logs CloudWatch de la Lambda 2
make avisos                             # las notificaciones ("el correo")
```

Qué verificar (misma tabla de verificación que en la nube):

| Dónde | Qué se espera |
|---|---|
| Respuesta del POST | `202` + `solicitudId` + `estado: RECIBIDA` |
| DynamoDB `solicitudes` | ítem con `estado: PROCESADA`, `resultado` y ambas fechas |
| SQS `solicitudes-pendientes` | 0 mensajes pendientes tras procesar |
| SQS `solicitudes-dlq` | siempre vacía (si tiene mensajes, el procesamiento falló 3 veces) |
| SNS (`make avisos`) | el "correo": asunto "Solicitud ... procesada" + el cuerpo con el resultado |
| CloudWatch logs | logs de recepción y de procesamiento |

> **Detalle técnico que verás en SQS:** cada vez que lees una cola, los mensajes leídos
> quedan "invisibles" (visibility timeout) por ~30 s. Si justo antes habías visto mensajes
> y ahora no aparecen, no se perdieron: espera 30 s y vuelve a consultar.

## Experimentos para perder el miedo (así se entiende de verdad)

1. **¿Qué pasa si las dos Lambdas "caen"?** Baja LocalStack (`make down`) justo después
   del POST: el mensaje **sigue en SQS** y no se pierde. Vuelve a subir (`make up` + `make init`)
   — ahí queda claro el principio del desacoplamiento: la cola retiene el trabajo.
2. **DLQ.** Elimina la Lambda de procesamiento
   (`docker exec localstack awslocal lambda delete-function --function-name procesamiento`),
   envía una solicitud (responde `202` igual: el POST no sabe que el procesador no existe,
   esa es la gracia de la cola) y mira la DLQ con `make estado`: tras 3 reintentos el mensaje
   cae a `solicitudes-dlq`. Recrea todo con `make down && make up && make init`.
3. **Picos de tráfico.** Envía 10 POST seguidos: todos responden `202` al instante
   aunque el procesamiento Java tarde. La cola amortigua el pico.

## Estructura del proyecto

```
paso01-local/
├── docker-compose.yml      LocalStack (todo AWS local en un contenedor)
├── Dockerfile.builder      Maven 21 en Docker: compila y corre pruebas
├── Makefile                comandos de la guía (build/up/init/demo/estado/down)
├── java/                   copia del código fuente (no se modifica el original)
├── scripts/
│   ├── init-aws.sh         crea TODA la infraestructura dentro de LocalStack
│   ├── demo.sh             POST de punta a punta + verificación en DynamoDB
│   ├── estado.sh           estado de tabla, colas, DLQ y suscripciones
│   └── avisos.sh           lee la bandeja simulada de notificaciones SNS
└── out/                    (generado) lambdas.zip listo para desplegar
```

## Limpieza

```bash
make down          # borra LocalStack + todo el estado (colas, tabla, logs)
make limpiar       # borra también el zip compilado
```

## Problemas frecuentes

| Síntoma | Solución |
|---|---|
| LocalStack arranca y muere pidiendo `LOCALSTACK_AUTH_TOKEN` | El compose fija `localstack/localstack:4.5.0` a propósito: las versiones "latest" actuales exigen licencia incluso para arrancar. Quédate en esa versión community |
| La primera invocación de Lambda tarda mucho | Se descarga la imagen `public.ecr.aws/lambda/java:21` y arranca la JVM (cold start de Java). Se ve con `docker ps` |
| La primera `make demo` tarda >2 min | Es el **cold start**: la imagen se descarga en el primer POST. Los siguientes procesan en segundos |
| `make init` dice que ya existe | No pasa nada: no re-crea (idempotente). Usa `make demo`, o re-crea con `make down && make up && make init` |
| No aparece la notificación en `make avisos` | Recuerda el visibility timeout: espera 30 s y reintenta. ¿Llegó la publicación? Revisa `make logs-procesamiento` (línea "SNS enviada") y DynamoDB |
| El ítem no aparece en DynamoDB y la DLQ tiene mensajes | `make logs-procesamiento` para ver el error; re-crea con `make down && make up && make init` |
| `Cannot connect to the Docker daemon` | Abre Docker Desktop antes de cualquier `make` |
| Puerto 4566 ocupado | Cierra otra instancia de LocalStack o cambia el puerto en `docker-compose.yml` |

## Mapa con el paso 02 (despliegue real en AWS)

Aquí terminas con `out/lambdas.zip` compilado. En el paso 02:

- el mismo jar se despliega con `sam deploy` (template.yaml del proyecto `solicitudes-serverless`).
- el destino cambia: de LocalStack a tu cuenta AWS Academy (Learner Lab).
- el flujo de verificación (`make demo` → `make estado`) lo repites con Postman y la consola AWS.

Sugerencia de cierre: compara el `scripts/init-aws.sh` con `template.yaml`: **declaran la misma
arquitectura**, uno con comandos y otro con infraestructura como código.
